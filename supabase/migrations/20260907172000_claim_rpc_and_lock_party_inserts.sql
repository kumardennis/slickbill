-- Claim public invoices in one security-definer RPC.
-- Then senders/receivers inserts are own-row only; invoice create uses service role.

create or replace function public.claim_public_invoice(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_me bigint := public.current_private_user_id();
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

  if p_token is null or length(trim(p_token)) = 0 then
    raise exception 'Missing public invoice token';
  end if;

  select * into v_public
  from public.public_digital_invoices
  where "publicToken" = trim(p_token)
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

revoke all on function public.claim_public_invoice(text) from public, anon;
grant execute on function public.claim_public_invoice(text) to authenticated, service_role;

drop policy if exists senders_insert_authenticated on public.senders;
create policy senders_insert_own
on public.senders for insert to authenticated
with check ("privateUserId" = public.current_private_user_id());

drop policy if exists receivers_insert_authenticated on public.receivers;
create policy receivers_insert_own
on public.receivers for insert to authenticated
with check (
  "privateUserId" = public.current_private_user_id()
  or exists (
    select 1
    from public.business_users bu
    join public.users u on u.id = bu."userId"
    where bu.id = receivers."businessUserId"
      and u."authUserId" = auth.uid()
  )
);
