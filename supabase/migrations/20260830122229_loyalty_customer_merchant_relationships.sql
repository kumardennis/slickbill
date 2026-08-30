-- Step 3c: Customer-facing merchant relationships (profile list + check-in sheet).

create or replace function public.merchant_public_name(p_merchant_private_user_id bigint)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(trim(pu."publicName"), ''),
    nullif(trim(concat_ws(' ', pu."firstName", pu."lastName")), ''),
    'Business'
  )
  from public.private_users pu
  where pu.id = p_merchant_private_user_id;
$$;

revoke all on function public.merchant_public_name(bigint) from public;
grant execute on function public.merchant_public_name(bigint) to authenticated;
grant execute on function public.merchant_public_name(bigint) to service_role;

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
    ),
    'merchantPublicName', public.merchant_public_name(v_merchant_id),
    'checkInCount', v_link.check_in_count,
    'paidInvoiceCount', v_link.paid_invoice_count,
    'totalPaidEur', v_link.total_paid_eur,
    'lastActiveMonth', to_char(
      coalesce(v_link.last_paid_at, v_link.last_check_in_at) at time zone 'UTC',
      'YYYY-MM'
    )
  );
end;
$$;

create or replace function public.customer_list_merchant_relationships(
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
  v_customer_id bigint;
begin
  v_customer_id := public.current_private_user_id();
  if v_customer_id is null then
    raise exception 'Not authenticated';
  end if;

  return coalesce((
    select json_agg(row_to_json(t))
    from (
      select
        public.merchant_public_name(l.merchant_private_user_id) as merchant_public_name,
        public.loyalty_badge_for_link(
          l.paid_invoice_count,
          l.last_paid_at,
          l.check_in_count,
          l.last_check_in_at
        ) as loyalty_badge,
        l.check_in_count,
        l.paid_invoice_count,
        l.total_paid_eur,
        to_char(
          coalesce(l.last_paid_at, l.last_check_in_at) at time zone 'UTC',
          'YYYY-MM'
        ) as last_active_month,
        l.first_check_in_at,
        l.last_check_in_at,
        l.first_paid_at,
        l.last_paid_at
      from public.merchant_customer_links l
      where l.customer_private_user_id = v_customer_id
      order by coalesce(l.last_paid_at, l.last_check_in_at) desc nulls last
      limit greatest(p_limit, 0)
      offset greatest(p_offset, 0)
    ) t
  ), '[]'::json);
end;
$$;

revoke all on function public.customer_list_merchant_relationships(integer, integer) from public;
grant execute on function public.customer_list_merchant_relationships(integer, integer) to authenticated;
grant execute on function public.customer_list_merchant_relationships(integer, integer) to service_role;
