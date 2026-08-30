-- Step 3a: Merchant checkout QR + check-in sessions (OPEN → cashier closes → CLOSED).

-- Lifetime link stats: allow check-in-only rows (no payment yet).
alter table public.merchant_customer_links
  alter column first_paid_at drop not null,
  alter column last_paid_at drop not null;

alter table public.merchant_customer_links
  add column if not exists first_check_in_at timestamptz,
  add column if not exists last_check_in_at timestamptz,
  add column if not exists check_in_count integer not null default 0;

alter table public.merchant_customer_links
  drop constraint if exists merchant_customer_links_check_in_count_check;

alter table public.merchant_customer_links
  add constraint merchant_customer_links_check_in_count_check
  check (check_in_count >= 0);

create index if not exists merchant_customer_links_merchant_last_check_in_idx
  on public.merchant_customer_links (merchant_private_user_id, last_check_in_at desc nulls last);

-- Opaque token encoded in printed QR (public at register).
create table if not exists public.merchant_checkout_qr (
  merchant_private_user_id bigint not null
    references public.private_users (id) on delete cascade,
  checkout_token text not null,
  created_at timestamptz not null default now(),
  rotated_at timestamptz,
  primary key (merchant_private_user_id),
  constraint merchant_checkout_qr_checkout_token_key unique (checkout_token)
);

alter table public.merchant_checkout_qr enable row level security;
revoke all on table public.merchant_checkout_qr from public;
revoke all on table public.merchant_checkout_qr from anon;
revoke all on table public.merchant_checkout_qr from authenticated;
grant all on table public.merchant_checkout_qr to service_role;

-- Counter visit: OPEN while customer at register, CLOSED by cashier.
create table if not exists public.merchant_check_in_sessions (
  id bigint generated always as identity primary key,
  merchant_private_user_id bigint not null
    references public.private_users (id) on delete cascade,
  customer_private_user_id bigint not null
    references public.private_users (id) on delete cascade,
  status text not null default 'OPEN',
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  closed_by_merchant_private_user_id bigint
    references public.private_users (id) on delete set null,
  constraint merchant_check_in_sessions_status_check
    check (status in ('OPEN', 'CLOSED'))
);

create index if not exists merchant_check_in_sessions_merchant_open_idx
  on public.merchant_check_in_sessions (merchant_private_user_id, opened_at desc)
  where status = 'OPEN';

create unique index if not exists merchant_check_in_sessions_one_open_per_pair_idx
  on public.merchant_check_in_sessions (merchant_private_user_id, customer_private_user_id)
  where status = 'OPEN';

alter table public.merchant_check_in_sessions enable row level security;
revoke all on table public.merchant_check_in_sessions from public;
revoke all on table public.merchant_check_in_sessions from anon;
revoke all on table public.merchant_check_in_sessions from authenticated;
grant all on table public.merchant_check_in_sessions to service_role;

create or replace function public.assert_current_business_merchant()
returns bigint
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_merchant_id bigint;
begin
  v_merchant_id := public.current_private_user_id();
  if v_merchant_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.private_users pu
    where pu.id = v_merchant_id
      and pu."isBusiness" is true
  ) then
    raise exception 'Business account required';
  end if;

  return v_merchant_id;
end;
$$;

revoke all on function public.assert_current_business_merchant() from public;
grant execute on function public.assert_current_business_merchant() to authenticated;
grant execute on function public.assert_current_business_merchant() to service_role;

create or replace function public.loyalty_badge_for_link(
  p_paid_invoice_count integer,
  p_last_paid_at timestamptz,
  p_check_in_count integer default 0,
  p_last_check_in_at timestamptz default null
)
returns text
language sql
stable
as $$
  select case
    when (
      p_paid_invoice_count >= 3
      and p_last_paid_at is not null
      and p_last_paid_at > (now() - interval '90 days')
    ) or (
      p_check_in_count >= 3
      and p_last_check_in_at is not null
      and p_last_check_in_at > (now() - interval '90 days')
    ) then 'regular'
    when p_paid_invoice_count >= 2 or p_check_in_count >= 2 then 'returning'
    else 'new'
  end;
$$;

create or replace function public.upsert_merchant_customer_check_in(
  p_merchant_private_user_id bigint,
  p_customer_private_user_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.merchant_customer_links (
    merchant_private_user_id,
    customer_private_user_id,
    first_check_in_at,
    last_check_in_at,
    check_in_count,
    paid_invoice_count,
    total_paid_eur
  ) values (
    p_merchant_private_user_id,
    p_customer_private_user_id,
    now(),
    now(),
    1,
    0,
    0
  )
  on conflict (merchant_private_user_id, customer_private_user_id)
  do update set
    first_check_in_at = coalesce(
      merchant_customer_links.first_check_in_at,
      now()
    ),
    last_check_in_at = now(),
    check_in_count = merchant_customer_links.check_in_count + 1;
end;
$$;

revoke all on function public.upsert_merchant_customer_check_in(bigint, bigint) from public;
grant execute on function public.upsert_merchant_customer_check_in(bigint, bigint) to service_role;

-- Paid path: support rows created by check-in first (nullable paid timestamps).
create or replace function public.handle_invoice_paid_merchant_customer_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_merchant_private_user_id bigint;
  v_customer_private_user_id bigint;
  v_amount numeric(14, 2);
begin
  if new.status is distinct from 'PAID' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'PAID' then
    return new;
  end if;

  if coalesce(new."senderIsBusiness", false) is not true then
    return new;
  end if;

  select s."privateUserId"
    into v_merchant_private_user_id
  from public.senders s
  where s.id = new."senderId";

  select r."privateUserId"
    into v_customer_private_user_id
  from public.receivers r
  where r.id = new."receiverId";

  if v_merchant_private_user_id is null
    or v_customer_private_user_id is null
    or v_merchant_private_user_id = v_customer_private_user_id then
    return new;
  end if;

  v_amount := round(coalesce(new.amount, 0)::numeric, 2);

  insert into public.merchant_customer_links (
    merchant_private_user_id,
    customer_private_user_id,
    first_paid_at,
    last_paid_at,
    paid_invoice_count,
    total_paid_eur
  ) values (
    v_merchant_private_user_id,
    v_customer_private_user_id,
    now(),
    now(),
    1,
    v_amount
  )
  on conflict (merchant_private_user_id, customer_private_user_id)
  do update set
    first_paid_at = coalesce(merchant_customer_links.first_paid_at, now()),
    last_paid_at = now(),
    paid_invoice_count = merchant_customer_links.paid_invoice_count + 1,
    total_paid_eur = merchant_customer_links.total_paid_eur + v_amount;

  return new;
end;
$$;

create or replace function public.merchant_get_checkout_qr()
returns json
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_merchant_id bigint;
  v_token text;
begin
  v_merchant_id := public.assert_current_business_merchant();

  insert into public.merchant_checkout_qr (
    merchant_private_user_id,
    checkout_token
  ) values (
    v_merchant_id,
    replace(gen_random_uuid()::text, '-', '')
  )
  on conflict (merchant_private_user_id) do nothing;

  select q.checkout_token
    into v_token
  from public.merchant_checkout_qr q
  where q.merchant_private_user_id = v_merchant_id;

  return json_build_object(
    'checkoutToken', v_token,
    'checkoutUrl', 'https://app.slickbills.com/m/' || v_token
  );
end;
$$;

create or replace function public.merchant_check_in(p_checkout_token text)
returns json
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_customer_id bigint;
  v_merchant_id bigint;
  v_session_id bigint;
  v_link public.merchant_customer_links%rowtype;
begin
  v_customer_id := public.current_private_user_id();
  if v_customer_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_checkout_token is null or length(trim(p_checkout_token)) = 0 then
    raise exception 'Invalid checkout token';
  end if;

  select q.merchant_private_user_id
    into v_merchant_id
  from public.merchant_checkout_qr q
  where q.checkout_token = trim(p_checkout_token);

  if v_merchant_id is null then
    raise exception 'Unknown checkout QR';
  end if;

  if v_merchant_id = v_customer_id then
    raise exception 'Cannot check in to your own business QR';
  end if;

  if not exists (
    select 1
    from public.private_users pu
    where pu.id = v_merchant_id
      and pu."isBusiness" is true
  ) then
    raise exception 'Merchant is not a business account';
  end if;

  perform public.upsert_merchant_customer_check_in(v_merchant_id, v_customer_id);

  select *
    into v_link
  from public.merchant_customer_links l
  where l.merchant_private_user_id = v_merchant_id
    and l.customer_private_user_id = v_customer_id;

  select s.id
    into v_session_id
  from public.merchant_check_in_sessions s
  where s.merchant_private_user_id = v_merchant_id
    and s.customer_private_user_id = v_customer_id
    and s.status = 'OPEN'
  limit 1;

  if v_session_id is null then
    insert into public.merchant_check_in_sessions (
      merchant_private_user_id,
      customer_private_user_id,
      status,
      opened_at
    ) values (
      v_merchant_id,
      v_customer_id,
      'OPEN',
      now()
    )
    returning id into v_session_id;
  else
    update public.merchant_check_in_sessions
    set opened_at = now()
    where id = v_session_id;
  end if;

  return json_build_object(
    'sessionId', v_session_id,
    'status', 'OPEN',
    'loyaltyBadge', public.loyalty_badge_for_link(
      v_link.paid_invoice_count,
      v_link.last_paid_at,
      v_link.check_in_count,
      v_link.last_check_in_at
    )
  );
end;
$$;

create or replace function public.merchant_list_open_sessions()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_merchant_id bigint;
begin
  v_merchant_id := public.assert_current_business_merchant();

  return coalesce((
    select json_agg(row_to_json(t))
    from (
      select
        s.id as session_id,
        s.opened_at,
        public.loyalty_badge_for_link(
          l.paid_invoice_count,
          l.last_paid_at,
          l.check_in_count,
          l.last_check_in_at
        ) as loyalty_badge,
        l.paid_invoice_count,
        l.check_in_count,
        l.total_paid_eur
      from public.merchant_check_in_sessions s
      inner join public.merchant_customer_links l
        on l.merchant_private_user_id = s.merchant_private_user_id
       and l.customer_private_user_id = s.customer_private_user_id
      where s.merchant_private_user_id = v_merchant_id
        and s.status = 'OPEN'
      order by s.opened_at desc
    ) t
  ), '[]'::json);
end;
$$;

create or replace function public.merchant_close_check_in_session(p_session_id bigint)
returns json
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_merchant_id bigint;
  v_row public.merchant_check_in_sessions%rowtype;
begin
  v_merchant_id := public.assert_current_business_merchant();

  select *
    into v_row
  from public.merchant_check_in_sessions s
  where s.id = p_session_id
    and s.merchant_private_user_id = v_merchant_id;

  if v_row.id is null then
    raise exception 'Session not found';
  end if;

  if v_row.status = 'CLOSED' then
    return json_build_object('sessionId', v_row.id, 'status', 'CLOSED');
  end if;

  update public.merchant_check_in_sessions
  set
    status = 'CLOSED',
    closed_at = now(),
    closed_by_merchant_private_user_id = v_merchant_id
  where id = p_session_id;

  return json_build_object('sessionId', p_session_id, 'status', 'CLOSED');
end;
$$;

create or replace function public.merchant_list_customers(
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
  v_merchant_id bigint;
begin
  v_merchant_id := public.assert_current_business_merchant();

  return coalesce((
    select json_agg(row_to_json(t))
    from (
      select
        public.loyalty_badge_for_link(
          l.paid_invoice_count,
          l.last_paid_at,
          l.check_in_count,
          l.last_check_in_at
        ) as loyalty_badge,
        l.paid_invoice_count,
        l.check_in_count,
        l.total_paid_eur,
        to_char(
          coalesce(l.last_paid_at, l.last_check_in_at) at time zone 'UTC',
          'YYYY-MM'
        ) as last_active_month,
        l.first_paid_at,
        l.last_paid_at,
        l.first_check_in_at,
        l.last_check_in_at
      from public.merchant_customer_links l
      where l.merchant_private_user_id = v_merchant_id
      order by coalesce(l.last_paid_at, l.last_check_in_at) desc nulls last
      limit greatest(p_limit, 0)
      offset greatest(p_offset, 0)
    ) t
  ), '[]'::json);
end;
$$;

create or replace function public.merchant_get_dashboard()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_merchant_id bigint;
  v_result json;
begin
  v_merchant_id := public.assert_current_business_merchant();

  select json_build_object(
    'uniqueCustomers', count(*)::integer,
    'repeatCustomers', count(*) filter (
      where paid_invoice_count >= 2 or check_in_count >= 2
    )::integer,
    'totalReceivedEur', coalesce(sum(total_paid_eur), 0),
    'regularCustomers', count(*) filter (
      where public.loyalty_badge_for_link(
        paid_invoice_count,
        last_paid_at,
        check_in_count,
        last_check_in_at
      ) = 'regular'
    )::integer,
    'openSessions', (
      select count(*)::integer
      from public.merchant_check_in_sessions s
      where s.merchant_private_user_id = v_merchant_id
        and s.status = 'OPEN'
    )
  )
  into v_result
  from public.merchant_customer_links
  where merchant_private_user_id = v_merchant_id;

  return coalesce(v_result, json_build_object(
    'uniqueCustomers', 0,
    'repeatCustomers', 0,
    'totalReceivedEur', 0,
    'regularCustomers', 0,
    'openSessions', 0
  ));
end;
$$;

revoke all on function public.merchant_get_checkout_qr() from public;
revoke all on function public.merchant_check_in(text) from public;
revoke all on function public.merchant_list_open_sessions() from public;
revoke all on function public.merchant_close_check_in_session(bigint) from public;
grant execute on function public.merchant_get_checkout_qr() to authenticated;
grant execute on function public.merchant_check_in(text) to authenticated;
grant execute on function public.merchant_list_open_sessions() to authenticated;
grant execute on function public.merchant_close_check_in_session(bigint) to authenticated;
grant execute on function public.merchant_get_checkout_qr() to service_role;
grant execute on function public.merchant_check_in(text) to service_role;
grant execute on function public.merchant_list_open_sessions() to service_role;
grant execute on function public.merchant_close_check_in_session(bigint) to service_role;
