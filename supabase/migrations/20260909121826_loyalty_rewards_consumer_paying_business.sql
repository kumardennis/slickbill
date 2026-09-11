-- Rewards are a consumer promo: earn only when a private account pays a
-- business invoice. Business payers and P2P (private→private) do not earn.

create or replace function public.rewards_earn_for_invoice(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.digital_invoices%rowtype;
  v_payer_id bigint;
  v_sender_id bigint;
  v_payer_is_business boolean;
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

  if coalesce(v_invoice."senderIsBusiness", false) is not true then
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

  select s."privateUserId"
    into v_sender_id
  from public.senders s
  where s.id = v_invoice."senderId";

  if v_payer_id is null or v_sender_id is null or v_payer_id = v_sender_id then
    return;
  end if;

  select coalesce(pu."isBusiness", false)
    into v_payer_is_business
  from public.private_users pu
  where pu.id = v_payer_id;

  if coalesce(v_payer_is_business, false) is true then
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

-- Drop ineligible Phase 0 earns (redemption is not live).
do $$
declare
  v_user_id bigint;
begin
  for v_user_id in
    with deleted as (
      delete from public.rewards_ledger rl
      where rl.entry_type = 'EARN'
        and rl.status in ('PENDING', 'LOCKED')
        and exists (
          select 1
          from public.digital_invoices di
          left join public.receivers r
            on r.id = di."receiverId"
          left join public.senders s
            on s.id = di."senderId"
          left join public.private_users payer
            on payer.id = r."privateUserId"
          where di.id = rl.invoice_id
            and (
              coalesce(di."senderIsBusiness", false) is not true
              or coalesce(payer."isBusiness", false) is true
              or r."privateUserId" is null
              or s."privateUserId" is null
              or r."privateUserId" = s."privateUserId"
            )
        )
      returning rl.private_user_id
    )
    select distinct private_user_id from deleted
  loop
    perform public.refresh_rewards_wallet_cache(v_user_id);
  end loop;
end;
$$;
