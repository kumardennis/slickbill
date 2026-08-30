-- Fix merchant_list_open_sessions: ORDER BY mrow.joined_at requires joined_at in subquery.

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
    select json_agg(row_to_json(t) order by t.opened_at desc)
    from (
      select
        s.id as session_id,
        s.session_token,
        s.opened_at,
        (
          select count(*)::integer
          from public.merchant_check_in_session_members mm
          where mm.session_id = s.id
        ) as member_count,
        coalesce((
          select json_agg(row_to_json(mrow) order by mrow.joined_at asc)
          from (
            select
              mem.member_token,
              mem.joined_at,
              public.loyalty_badge_for_link(
                l.paid_invoice_count,
                l.last_paid_at,
                l.check_in_count,
                l.last_check_in_at
              ) as loyalty_badge,
              l.paid_invoice_count,
              l.check_in_count,
              l.total_paid_eur
            from public.merchant_check_in_session_members mem
            inner join public.merchant_customer_links l
              on l.merchant_private_user_id = s.merchant_private_user_id
             and l.customer_private_user_id = mem.customer_private_user_id
            where mem.session_id = s.id
          ) mrow
        ), '[]'::json) as members
      from public.merchant_check_in_sessions s
      where s.merchant_private_user_id = v_merchant_id
        and s.status = 'OPEN'
    ) t
  ), '[]'::json);
end;
$$;

revoke all on function public.merchant_list_open_sessions() from public;
grant execute on function public.merchant_list_open_sessions() to authenticated;
grant execute on function public.merchant_list_open_sessions() to service_role;
