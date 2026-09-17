-- publicToken is uuid; RPCs compared it to text and failed with
-- "operator does not exist: uuid = text" when a QR / bill link was opened.

create or replace function public.parse_public_invoice_token(p_token text)
returns uuid
language plpgsql
immutable
set search_path = public
as $$
begin
  if p_token is null or length(trim(p_token)) = 0 then
    return null;
  end if;
  return trim(p_token)::uuid;
exception
  when invalid_text_representation then
    return null;
end;
$$;

revoke all on function public.parse_public_invoice_token(text) from public;
grant execute on function public.parse_public_invoice_token(text)
  to anon, authenticated, service_role;

create or replace function public.get_public_invoice_by_token(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token uuid := public.parse_public_invoice_token(p_token);
  v_invoice jsonb;
  v_sender jsonb;
begin
  if v_token is null then
    return null;
  end if;

  select to_jsonb(i) into v_invoice
  from public.public_digital_invoices i
  where i."publicToken" = v_token
  limit 1;

  if v_invoice is null then
    return null;
  end if;

  select jsonb_build_object(
    'id', pu.id,
    'created_at', pu.created_at,
    'firstName', pu."firstName",
    'lastName', pu."lastName",
    'userId', pu."userId",
    'iban', pu.iban,
    'bankAccountName', pu."bankAccountName",
    'isBusiness', pu."isBusiness",
    'publicName', pu."publicName"
  )
  into v_sender
  from public.private_users pu
  where pu.id = (v_invoice->>'senderPrivateUserId')::bigint;

  return v_invoice || jsonb_build_object('sender', v_sender);
end;
$$;

create or replace function public.increment_public_invoice_view(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token uuid := public.parse_public_invoice_token(p_token);
begin
  if v_token is null then
    return;
  end if;

  update public.public_digital_invoices
  set "viewCount" = coalesce("viewCount", 0) + 1
  where "publicToken" = v_token;
end;
$$;

create or replace function public.claim_public_invoice(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_me bigint := public.current_private_user_id();
  v_token uuid := public.parse_public_invoice_token(p_token);
  v_public public.public_digital_invoices%rowtype;
  v_existing_id bigint;
  v_sender_id bigint;
  v_receiver_id bigint;
  v_digital public.digital_invoices%rowtype;
  v_result jsonb;
begin
  if auth.uid() is null or v_me is null then
    raise exception 'Not authenticated';
  end if;

  if v_token is null then
    raise exception 'Missing public invoice token';
  end if;

  select * into v_public
  from public.public_digital_invoices
  where "publicToken" = v_token
  limit 1;

  if not found then
    raise exception 'Invoice not found';
  end if;

  select c.digital_invoice_id into v_existing_id
  from public.public_invoice_claims c
  where c.public_invoice_id = v_public.id
    and c.claimed_by_user_id = v_me
  limit 1;

  if v_existing_id is not null then
    select to_jsonb(di) || jsonb_build_object('alreadyClaimed', true)
    into v_result
    from public.digital_invoices di
    where di.id = v_existing_id;
    return v_result;
  end if;

  insert into public.senders ("privateUserId")
  values (v_public."senderPrivateUserId")
  returning id into v_sender_id;

  insert into public.receivers ("privateUserId")
  values (v_me)
  returning id into v_receiver_id;

  insert into public.digital_invoices (
    "senderId",
    "receiverId",
    amount,
    description,
    category,
    status,
    deadline,
    "senderIban",
    "senderName",
    "senderIsBusiness",
    "referenceNo",
    "invoiceNo",
    "receiverPrivateUserId",
    "senderPrivateUserId",
    "originalInvoiceNo",
    data,
    "isSeen"
  )
  values (
    v_sender_id,
    v_receiver_id,
    v_public.amount,
    v_public.description,
    v_public.category,
    v_public.status,
    v_public.deadline,
    v_public."senderIban",
    v_public."senderName",
    v_public."senderIsBusiness",
    v_public."referenceNo",
    v_me::text || (extract(epoch from now()) * 1000)::bigint::text,
    v_me,
    v_public."senderPrivateUserId",
    v_public."originalInvoiceNo",
    v_public.data,
    false
  )
  returning * into v_digital;

  insert into public.public_invoice_claims (
    public_invoice_id,
    digital_invoice_id,
    claimed_by_user_id
  )
  values (v_public.id, v_digital.id, v_me);

  update public.public_digital_invoices
  set
    "viewCount" = coalesce("viewCount", 0) + 1,
    "claimCount" = coalesce("claimCount", 0) + 1
  where id = v_public.id;

  return to_jsonb(v_digital) || jsonb_build_object('alreadyClaimed', false);
end;
$$;

revoke all on function public.get_public_invoice_by_token(text) from public;
grant execute on function public.get_public_invoice_by_token(text)
  to anon, authenticated, service_role;

revoke all on function public.increment_public_invoice_view(text) from public;
grant execute on function public.increment_public_invoice_view(text)
  to anon, authenticated, service_role;

revoke all on function public.claim_public_invoice(text) from public, anon;
grant execute on function public.claim_public_invoice(text)
  to authenticated, service_role;
