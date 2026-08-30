-- Step 4: SlickBills Rewards Phase 0 (accumulate + claim → locked; no redemption).

create table if not exists public.platform_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

insert into public.platform_config (key, value)
values
  ('rewards_earn_enabled', 'true'::jsonb),
  ('rewards_redemption_enabled', 'false'::jsonb),
  ('rewards_earn_rate_bps', '100'::jsonb),
  ('rewards_min_earn_amount', '0.01'::jsonb),
  ('rewards_max_earn_per_invoice', '5.00'::jsonb)
on conflict (key) do nothing;

alter table public.platform_config enable row level security;
revoke all on table public.platform_config from public;
revoke all on table public.platform_config from anon;
revoke all on table public.platform_config from authenticated;
grant select on table public.platform_config to service_role;

create table if not exists public.rewards_ledger (
  id bigint generated always as identity primary key,
  private_user_id bigint not null
    references public.private_users (id) on delete cascade,
  entry_type text not null,
  amount numeric(14, 4) not null,
  status text not null,
  invoice_id bigint
    references public.digital_invoices (id) on delete set null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  constraint rewards_ledger_entry_type_check
    check (entry_type in ('EARN', 'CLAIM', 'REDEEM', 'EXPIRE', 'ADJUST')),
  constraint rewards_ledger_status_check
    check (status in ('PENDING', 'LOCKED', 'ACTIVE', 'REDEEMED', 'EXPIRED')),
  constraint rewards_ledger_amount_check
    check (amount > 0)
);

create unique index if not exists rewards_ledger_one_earn_per_invoice_idx
  on public.rewards_ledger (invoice_id)
  where entry_type = 'EARN' and invoice_id is not null;

create index if not exists rewards_ledger_user_created_idx
  on public.rewards_ledger (private_user_id, created_at desc);

create index if not exists rewards_ledger_user_status_idx
  on public.rewards_ledger (private_user_id, status);

alter table public.rewards_ledger enable row level security;
revoke all on table public.rewards_ledger from public;
revoke all on table public.rewards_ledger from anon;
revoke all on table public.rewards_ledger from authenticated;
grant all on table public.rewards_ledger to service_role;

create table if not exists public.rewards_wallet_cache (
  private_user_id bigint primary key
    references public.private_users (id) on delete cascade,
  pending_amount numeric(14, 4) not null default 0,
  locked_amount numeric(14, 4) not null default 0,
  updated_at timestamptz not null default now(),
  constraint rewards_wallet_cache_pending_amount_check
    check (pending_amount >= 0),
  constraint rewards_wallet_cache_locked_amount_check
    check (locked_amount >= 0)
);

alter table public.rewards_wallet_cache enable row level security;
revoke all on table public.rewards_wallet_cache from public;
revoke all on table public.rewards_wallet_cache from anon;
revoke all on table public.rewards_wallet_cache from authenticated;
grant all on table public.rewards_wallet_cache to service_role;

create or replace function public.platform_config_bool(
  p_key text,
  p_default boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select case
        when jsonb_typeof(c.value) = 'boolean' then (c.value #>> '{}')::boolean
        when jsonb_typeof(c.value) = 'string' then lower(c.value #>> '{}') in ('true', '1', 'yes')
        when jsonb_typeof(c.value) = 'number' then (c.value #>> '{}')::numeric <> 0
        else p_default
      end
      from public.platform_config c
      where c.key = p_key
    ),
    p_default
  );
$$;

create or replace function public.platform_config_numeric(
  p_key text,
  p_default numeric default 0
)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select (c.value #>> '{}')::numeric
      from public.platform_config c
      where c.key = p_key
    ),
    p_default
  );
$$;

create or replace function public.refresh_rewards_wallet_cache(p_private_user_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.rewards_wallet_cache (
    private_user_id,
    pending_amount,
    locked_amount,
    updated_at
  )
  select
    p_private_user_id,
    coalesce(sum(l.amount) filter (
      where l.entry_type = 'EARN' and l.status = 'PENDING'
    ), 0),
    coalesce(sum(l.amount) filter (
      where l.entry_type = 'EARN' and l.status = 'LOCKED'
    ), 0),
    now()
  from public.rewards_ledger l
  where l.private_user_id = p_private_user_id
  on conflict (private_user_id) do update set
    pending_amount = excluded.pending_amount,
    locked_amount = excluded.locked_amount,
    updated_at = excluded.updated_at;
end;
$$;

create or replace function public.rewards_earn_for_invoice(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.digital_invoices%rowtype;
  v_payer_id bigint;
  v_invoice_amount numeric(14, 2);
  v_rate_bps numeric;
  v_min_earn numeric;
  v_max_earn numeric;
  v_earn_amount numeric(14, 4);
begin
  if p_invoice_id is null then
    return;
  end if;

  if not public.platform_config_bool('rewards_earn_enabled', true) then
    return;
  end if;

  select *
    into v_invoice
  from public.digital_invoices di
  where di.id = p_invoice_id;

  if v_invoice.id is null or v_invoice.status is distinct from 'PAID' then
    return;
  end if;

  if exists (
    select 1
    from public.rewards_ledger rl
    where rl.invoice_id = p_invoice_id
      and rl.entry_type = 'EARN'
  ) then
    return;
  end if;

  select r."privateUserId"
    into v_payer_id
  from public.receivers r
  where r.id = v_invoice."receiverId";

  if v_payer_id is null then
    return;
  end if;

  v_invoice_amount := round(coalesce(v_invoice.amount, 0)::numeric, 2);
  if v_invoice_amount <= 0 then
    return;
  end if;

  v_rate_bps := public.platform_config_numeric('rewards_earn_rate_bps', 100);
  v_min_earn := public.platform_config_numeric('rewards_min_earn_amount', 0.01);
  v_max_earn := public.platform_config_numeric('rewards_max_earn_per_invoice', 5.00);

  v_earn_amount := round(v_invoice_amount * v_rate_bps / 10000.0, 4);
  v_earn_amount := least(v_earn_amount, v_max_earn);

  if v_earn_amount < v_min_earn then
    return;
  end if;

  insert into public.rewards_ledger (
    private_user_id,
    entry_type,
    amount,
    status,
    invoice_id
  ) values (
    v_payer_id,
    'EARN',
    v_earn_amount,
    'PENDING',
    p_invoice_id
  );

  perform public.refresh_rewards_wallet_cache(v_payer_id);
end;
$$;

create or replace function public.handle_invoice_paid_rewards_earn()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from 'PAID' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'PAID' then
    return new;
  end if;

  perform public.rewards_earn_for_invoice(new.id);
  return new;
end;
$$;

drop trigger if exists trg_invoice_paid_rewards_earn on public.digital_invoices;

create trigger trg_invoice_paid_rewards_earn
after insert or update of status on public.digital_invoices
for each row
execute function public.handle_invoice_paid_rewards_earn();

create or replace function public.rewards_get_summary()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user_id bigint;
  v_pending numeric(14, 4);
  v_locked numeric(14, 4);
begin
  v_user_id := public.current_private_user_id();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select
    coalesce(w.pending_amount, 0),
    coalesce(w.locked_amount, 0)
  into v_pending, v_locked
  from public.rewards_wallet_cache w
  where w.private_user_id = v_user_id;

  return json_build_object(
    'pendingAmount', coalesce(v_pending, 0),
    'lockedAmount', coalesce(v_locked, 0),
    'earnEnabled', public.platform_config_bool('rewards_earn_enabled', true),
    'redemptionEnabled', public.platform_config_bool('rewards_redemption_enabled', false),
    'recentEntries', coalesce((
      select json_agg(row_to_json(t))
      from (
        select
          l.id,
          l.entry_type,
          l.amount,
          l.status,
          l.invoice_id,
          l.expires_at,
          l.created_at
        from public.rewards_ledger l
        where l.private_user_id = v_user_id
        order by l.created_at desc
        limit 10
      ) t
    ), '[]'::json)
  );
end;
$$;

create or replace function public.rewards_list_history(
  p_limit integer default 50,
  p_offset integer default 0
)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user_id bigint;
begin
  v_user_id := public.current_private_user_id();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  return coalesce((
    select json_agg(row_to_json(t))
    from (
      select
        l.id,
        l.entry_type,
        l.amount,
        l.status,
        l.invoice_id,
        l.expires_at,
        l.created_at
      from public.rewards_ledger l
      where l.private_user_id = v_user_id
      order by l.created_at desc
      limit greatest(p_limit, 0)
      offset greatest(p_offset, 0)
    ) t
  ), '[]'::json);
end;
$$;

create or replace function public.rewards_claim_pending()
returns json
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_user_id bigint;
  v_claimed_amount numeric(14, 4);
begin
  v_user_id := public.current_private_user_id();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select coalesce(sum(l.amount), 0)
    into v_claimed_amount
  from public.rewards_ledger l
  where l.private_user_id = v_user_id
    and l.entry_type = 'EARN'
    and l.status = 'PENDING';

  if v_claimed_amount <= 0 then
    return json_build_object(
      'claimedAmount', 0,
      'pendingAmount', 0,
      'lockedAmount', coalesce((
        select w.locked_amount
        from public.rewards_wallet_cache w
        where w.private_user_id = v_user_id
      ), 0)
    );
  end if;

  update public.rewards_ledger
  set
    status = 'LOCKED',
    expires_at = now() + interval '2 years'
  where private_user_id = v_user_id
    and entry_type = 'EARN'
    and status = 'PENDING';

  perform public.refresh_rewards_wallet_cache(v_user_id);

  return json_build_object(
    'claimedAmount', v_claimed_amount,
    'pendingAmount', coalesce((
      select w.pending_amount
      from public.rewards_wallet_cache w
      where w.private_user_id = v_user_id
    ), 0),
    'lockedAmount', coalesce((
      select w.locked_amount
      from public.rewards_wallet_cache w
      where w.private_user_id = v_user_id
    ), 0)
  );
end;
$$;

revoke all on function public.platform_config_bool(text, boolean) from public;
revoke all on function public.platform_config_numeric(text, numeric) from public;
revoke all on function public.refresh_rewards_wallet_cache(bigint) from public;
revoke all on function public.rewards_earn_for_invoice(bigint) from public;
revoke all on function public.rewards_get_summary() from public;
revoke all on function public.rewards_list_history(integer, integer) from public;
revoke all on function public.rewards_claim_pending() from public;

grant execute on function public.rewards_get_summary() to authenticated;
grant execute on function public.rewards_list_history(integer, integer) to authenticated;
grant execute on function public.rewards_claim_pending() to authenticated;

grant execute on function public.rewards_get_summary() to service_role;
grant execute on function public.rewards_list_history(integer, integer) to service_role;
grant execute on function public.rewards_claim_pending() to service_role;
grant execute on function public.rewards_earn_for_invoice(bigint) to service_role;
grant execute on function public.refresh_rewards_wallet_cache(bigint) to service_role;
