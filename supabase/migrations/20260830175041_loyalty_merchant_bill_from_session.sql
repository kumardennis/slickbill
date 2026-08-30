-- Step 3e: Merchant bills a checked-in member via session (server resolves customer id).

create or replace function public.merchant_sender_display_name(p_merchant_private_user_id bigint)
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

revoke all on function public.merchant_sender_display_name(bigint) from public;
grant execute on function public.merchant_sender_display_name(bigint) to service_role;

create or replace function public.merchant_create_invoice_for_session(
  p_session_id bigint,
  p_member_token text,
  p_amount numeric,
  p_description text default null,
  p_due_date date default null,
  p_reference_no text default null,
  p_category text default 'General'
)
returns json
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_merchant_id bigint;
  v_session public.merchant_check_in_sessions%rowtype;
  v_customer_private_user_id bigint;
  v_customer_user_id bigint;
  v_sender_id bigint;
  v_receiver_id bigint;
  v_invoice_id bigint;
  v_sender_name text;
  v_sender_iban text;
  v_amount numeric(14, 2);
  v_description text;
  v_due_date date;
  v_member_token text;
begin
  v_merchant_id := public.assert_current_business_merchant();

  if p_session_id is null or p_session_id <= 0 then
    raise exception 'Session not found';
  end if;

  v_member_token := trim(coalesce(p_member_token, ''));
  if v_member_token = '' then
    raise exception 'Member token required';
  end if;

  v_amount := round(coalesce(p_amount, 0)::numeric, 2);
  if v_amount <= 0 then
    raise exception 'Amount must be greater than zero';
  end if;

  select *
    into v_session
  from public.merchant_check_in_sessions s
  where s.id = p_session_id
    and s.merchant_private_user_id = v_merchant_id
    and s.status = 'OPEN';

  if v_session.id is null then
    raise exception 'Session not found';
  end if;

  select m.customer_private_user_id
    into v_customer_private_user_id
  from public.merchant_check_in_session_members m
  where m.session_id = p_session_id
    and m.member_token = v_member_token;

  if v_customer_private_user_id is null then
    raise exception 'Member not found in this visit';
  end if;

  select pu."userId"
    into v_customer_user_id
  from public.private_users pu
  where pu.id = v_customer_private_user_id;

  if v_customer_user_id is null then
    raise exception 'Customer account not found';
  end if;

  select
    coalesce(nullif(trim(pu.iban), ''), ''),
    public.merchant_sender_display_name(v_merchant_id)
  into v_sender_iban, v_sender_name
  from public.private_users pu
  where pu.id = v_merchant_id;

  if v_sender_iban = '' then
    raise exception 'Add a payout IBAN on your profile before sending bills';
  end if;

  v_due_date := coalesce(
    p_due_date,
    (current_date + interval '7 days')::date
  );

  v_description := coalesce(
    nullif(trim(p_description), ''),
    format('Visit %s · %s', v_session.session_token, v_member_token)
  );

  insert into public.senders ("privateUserId")
  values (v_merchant_id)
  returning id into v_sender_id;

  insert into public.receivers ("privateUserId")
  values (v_customer_private_user_id)
  returning id into v_receiver_id;

  insert into public.digital_invoices (
    "senderId",
    "receiverId",
    amount,
    description,
    "senderName",
    "senderIban",
    "senderIsBusiness",
    deadline,
    "invoiceNo",
    "referenceNo",
    category,
    "receiverPrivateUserId",
    "senderPrivateUserId",
    status
  ) values (
    v_sender_id,
    v_receiver_id,
    v_amount,
    v_description,
    v_sender_name,
    v_sender_iban,
    true,
    v_due_date,
    v_merchant_id::text || extract(epoch from now())::bigint::text,
    nullif(trim(coalesce(p_reference_no, '')), ''),
    coalesce(nullif(trim(p_category), ''), 'General'),
    v_customer_private_user_id,
    v_merchant_id,
    'UNPAID'
  )
  returning id into v_invoice_id;

  return json_build_object(
    'invoiceId', v_invoice_id,
    'amount', v_amount,
    'sessionId', p_session_id,
    'sessionToken', v_session.session_token,
    'memberToken', v_member_token,
    'description', v_description,
    'dueDate', v_due_date
  );
end;
$$;

revoke all on function public.merchant_create_invoice_for_session(
  bigint, text, numeric, text, date, text, text
) from public;

grant execute on function public.merchant_create_invoice_for_session(
  bigint, text, numeric, text, date, text, text
) to authenticated;

grant execute on function public.merchant_create_invoice_for_session(
  bigint, text, numeric, text, date, text, text
) to service_role;

-- Group bill: merchant enters amount per session member (Direct Share / private_groups).
create or replace function public.merchant_create_group_invoice_for_session(
  p_session_id bigint,
  p_splits jsonb,
  p_description text default null,
  p_due_date date default null,
  p_reference_no text default null,
  p_category text default 'General'
)
returns json
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_merchant_id bigint;
  v_session public.merchant_check_in_sessions%rowtype;
  v_sender_name text;
  v_sender_iban text;
  v_due_date date;
  v_description text;
  v_group_id bigint;
  v_split jsonb;
  v_member_token text;
  v_amount numeric(14, 2);
  v_customer_private_user_id bigint;
  v_sender_id bigint;
  v_receiver_id bigint;
  v_invoice_id bigint;
  v_invoices jsonb := '[]'::jsonb;
  v_billed_count int := 0;
begin
  v_merchant_id := public.assert_current_business_merchant();

  if p_session_id is null or p_session_id <= 0 then
    raise exception 'Session not found';
  end if;

  if p_splits is null or jsonb_typeof(p_splits) <> 'array' or jsonb_array_length(p_splits) = 0 then
    raise exception 'Enter an amount for at least one guest';
  end if;

  select *
    into v_session
  from public.merchant_check_in_sessions s
  where s.id = p_session_id
    and s.merchant_private_user_id = v_merchant_id
    and s.status = 'OPEN';

  if v_session.id is null then
    raise exception 'Session not found';
  end if;

  select
    coalesce(nullif(trim(pu.iban), ''), ''),
    public.merchant_sender_display_name(v_merchant_id)
  into v_sender_iban, v_sender_name
  from public.private_users pu
  where pu.id = v_merchant_id;

  if v_sender_iban = '' then
    raise exception 'Add a payout IBAN on your profile before sending bills';
  end if;

  v_due_date := coalesce(
    p_due_date,
    (current_date + interval '7 days')::date
  );

  v_description := coalesce(
    nullif(trim(p_description), ''),
    format('Visit %s', v_session.session_token)
  );

  insert into public.private_groups ("creatorUserId", deadline, description)
  values (v_merchant_id, v_due_date, v_description)
  returning id into v_group_id;

  for v_split in select value from jsonb_array_elements(p_splits)
  loop
    v_member_token := trim(coalesce(v_split ->> 'member_token', ''));
    v_amount := round(coalesce((v_split ->> 'amount')::numeric, 0), 2);

    if v_member_token = '' or v_amount <= 0 then
      continue;
    end if;

    select m.customer_private_user_id
      into v_customer_private_user_id
    from public.merchant_check_in_session_members m
    where m.session_id = p_session_id
      and m.member_token = v_member_token;

    if v_customer_private_user_id is null then
      raise exception 'Member not found in this visit';
    end if;

    insert into public.senders ("privateUserId")
    values (v_merchant_id)
    returning id into v_sender_id;

    insert into public.receivers ("privateUserId")
    values (v_customer_private_user_id)
    returning id into v_receiver_id;

    insert into public.digital_invoices (
      "senderId",
      "receiverId",
      amount,
      description,
      "senderName",
      "senderIban",
      "senderIsBusiness",
      deadline,
      "invoiceNo",
      "referenceNo",
      category,
      "receiverPrivateUserId",
      "senderPrivateUserId",
      "privateGroupId",
      status
    ) values (
      v_sender_id,
      v_receiver_id,
      v_amount,
      v_description,
      v_sender_name,
      v_sender_iban,
      true,
      v_due_date,
      v_merchant_id::text || extract(epoch from now())::bigint::text || v_billed_count::text,
      nullif(trim(coalesce(p_reference_no, '')), ''),
      coalesce(nullif(trim(p_category), ''), 'General'),
      v_customer_private_user_id,
      v_merchant_id,
      v_group_id,
      'UNPAID'
    )
    returning id into v_invoice_id;

    v_invoices := v_invoices || jsonb_build_array(
      jsonb_build_object(
        'invoiceId', v_invoice_id,
        'memberToken', v_member_token,
        'amount', v_amount
      )
    );

    v_billed_count := v_billed_count + 1;
  end loop;

  if v_billed_count < 2 then
    raise exception 'Group bill requires amounts for at least two guests';
  end if;

  return json_build_object(
    'privateGroupId', v_group_id,
    'sessionId', p_session_id,
    'sessionToken', v_session.session_token,
    'description', v_description,
    'dueDate', v_due_date,
    'invoices', v_invoices
  );
end;
$$;

revoke all on function public.merchant_create_group_invoice_for_session(
  bigint, jsonb, text, date, text, text
) from public;

grant execute on function public.merchant_create_group_invoice_for_session(
  bigint, jsonb, text, date, text, text
) to authenticated;

grant execute on function public.merchant_create_group_invoice_for_session(
  bigint, jsonb, text, date, text, text
) to service_role;
