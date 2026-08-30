-- Phase 0: auto-save rewards on earn (no user claim step).

-- Backfill any legacy PENDING rows.
update public.rewards_ledger
set
  status = 'LOCKED',
  expires_at = coalesce(expires_at, created_at + interval '2 years')
where entry_type = 'EARN'
  and status = 'PENDING';

-- Refresh wallet caches for affected users.
do $$
declare
  v_user_id bigint;
begin
  for v_user_id in
    select distinct private_user_id
    from public.rewards_ledger
    where entry_type = 'EARN'
  loop
    perform public.refresh_rewards_wallet_cache(v_user_id);
  end loop;
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
    invoice_id,
    expires_at
  ) values (
    v_payer_id,
    'EARN',
    v_earn_amount,
    'LOCKED',
    p_invoice_id,
    now() + interval '2 years'
  );

  perform public.refresh_rewards_wallet_cache(v_payer_id);
end;
$$;

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
  v_total numeric(14, 4);
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

  v_total := coalesce(v_pending, 0) + coalesce(v_locked, 0);

  return json_build_object(
    'pendingAmount', coalesce(v_pending, 0),
    'lockedAmount', coalesce(v_locked, 0),
    'totalAmount', v_total,
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

-- Claim RPC kept for backwards compatibility; no longer exposed to clients.
revoke execute on function public.rewards_claim_pending() from authenticated;
