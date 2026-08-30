-- Step 1: Merchant ↔ customer links on invoice PAID (business senders only).
-- Real ids stored server-side; merchant RPCs omit customer identity (UI shows "This user").

create table if not exists public.merchant_customer_links (
  merchant_private_user_id bigint not null
    references public.private_users (id) on delete cascade,
  customer_private_user_id bigint not null
    references public.private_users (id) on delete cascade,
  first_paid_at timestamptz not null default now(),
  last_paid_at timestamptz not null default now(),
  paid_invoice_count integer not null default 0
    check (paid_invoice_count >= 0),
  total_paid_eur numeric(14, 2) not null default 0
    check (total_paid_eur >= 0),
  primary key (merchant_private_user_id, customer_private_user_id)
);

create index if not exists merchant_customer_links_merchant_last_paid_idx
  on public.merchant_customer_links (merchant_private_user_id, last_paid_at desc);

alter table public.merchant_customer_links enable row level security;

-- No direct client access; reads/writes via SECURITY DEFINER functions + trigger.
revoke all on table public.merchant_customer_links from public;
revoke all on table public.merchant_customer_links from anon;
revoke all on table public.merchant_customer_links from authenticated;
grant all on table public.merchant_customer_links to service_role;

-- Resolve caller's private_users.id from Supabase auth.
create or replace function public.current_private_user_id()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select pu.id
  from public.private_users pu
  inner join public.users u on u.id = pu."userId"
  where u."authUserId" = auth.uid()
  order by pu.id
  limit 1;
$$;

revoke all on function public.current_private_user_id() from public;
grant execute on function public.current_private_user_id() to authenticated;
grant execute on function public.current_private_user_id() to service_role;

create or replace function public.loyalty_badge_for_link(
  p_paid_invoice_count integer,
  p_last_paid_at timestamptz
)
returns text
language sql
stable
as $$
  select case
    when p_paid_invoice_count >= 3
      and p_last_paid_at > (now() - interval '90 days') then 'regular'
    when p_paid_invoice_count >= 2 then 'returning'
    else 'new'
  end;
$$;

-- Upsert link when a business invoice becomes PAID (idempotent on re-update).
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
    last_paid_at = now(),
    paid_invoice_count = merchant_customer_links.paid_invoice_count + 1,
    total_paid_eur = merchant_customer_links.total_paid_eur + v_amount;

  return new;
end;
$$;

-- First install only (migration runs once via supabase db push).
create trigger trg_invoice_paid_merchant_customer_link
after insert or update of status on public.digital_invoices
for each row
execute function public.handle_invoice_paid_merchant_customer_link();

-- Merchant KPIs (no customer ids or usernames).
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

  select json_build_object(
    'uniqueCustomers', count(*)::integer,
    'repeatCustomers', count(*) filter (where paid_invoice_count >= 2)::integer,
    'totalReceivedEur', coalesce(sum(total_paid_eur), 0),
    'regularCustomers', count(*) filter (
      where public.loyalty_badge_for_link(paid_invoice_count, last_paid_at) = 'regular'
    )::integer
  )
  into v_result
  from public.merchant_customer_links
  where merchant_private_user_id = v_merchant_id;

  return coalesce(v_result, json_build_object(
    'uniqueCustomers', 0,
    'repeatCustomers', 0,
    'totalReceivedEur', 0,
    'regularCustomers', 0
  ));
end;
$$;

-- Merchant customer list — stats + badge only (UI label: "This user").
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

  return coalesce((
    select json_agg(row_to_json(t))
    from (
      select
        public.loyalty_badge_for_link(
          l.paid_invoice_count,
          l.last_paid_at
        ) as loyalty_badge,
        l.paid_invoice_count,
        l.total_paid_eur,
        to_char(l.last_paid_at at time zone 'UTC', 'YYYY-MM') as last_active_month,
        l.first_paid_at,
        l.last_paid_at
      from public.merchant_customer_links l
      where l.merchant_private_user_id = v_merchant_id
      order by l.last_paid_at desc
      limit greatest(p_limit, 0)
      offset greatest(p_offset, 0)
    ) t
  ), '[]'::json);
end;
$$;

revoke all on function public.merchant_get_dashboard() from public;
revoke all on function public.merchant_list_customers(integer, integer) from public;
grant execute on function public.merchant_get_dashboard() to authenticated;
grant execute on function public.merchant_list_customers(integer, integer) to authenticated;
grant execute on function public.merchant_get_dashboard() to service_role;
grant execute on function public.merchant_list_customers(integer, integer) to service_role;
