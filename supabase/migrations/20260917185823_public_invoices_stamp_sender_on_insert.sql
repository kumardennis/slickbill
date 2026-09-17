-- Public invoice inserts were failing RLS because the client can send
-- senderPrivateUserId as null (explicit nulls skip column defaults), so
-- WITH CHECK (senderPrivateUserId = current_private_user_id()) rejected the row.
-- Stamp the sender from the JWT, and create via a definer RPC like claims.

create or replace function public.public_invoices_stamp_sender()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  -- Backend / service_role writes keep the provided sender.
  if auth.uid() is null then
    return new;
  end if;

  new."senderPrivateUserId" := public.current_private_user_id();

  if new."senderPrivateUserId" is null then
    raise exception 'Not authenticated as an app user';
  end if;

  return new;
end;
$$;

drop trigger if exists public_invoices_stamp_sender on public.public_digital_invoices;
create trigger public_invoices_stamp_sender
before insert on public.public_digital_invoices
for each row
execute function public.public_invoices_stamp_sender();

revoke all on function public.public_invoices_stamp_sender() from public, anon, authenticated;

-- INSERT ... RETURNING applies SELECT policies to the new row. Looking the
-- row up by id can miss it mid-insert; allow the owner via the new columns.
drop policy if exists public_invoices_select_owner_or_claimer on public.public_digital_invoices;
create policy public_invoices_select_owner_or_claimer
on public.public_digital_invoices for select to authenticated
using (
  "senderPrivateUserId" = public.current_private_user_id()
  or public.can_read_public_invoice(id)
);

create or replace function public.create_public_invoice(
  p_status text default 'UNPAID',
  p_amount double precision default 0,
  p_data json default null,
  p_description text default null,
  p_sender_name text default null,
  p_sender_is_business boolean default false,
  p_deadline text default null,
  p_invoice_no text default null,
  p_original_invoice_no text default null,
  p_reference_no text default null,
  p_sender_iban text default null,
  p_category text default null,
  p_private_group_id bigint default null,
  p_raw_invoice_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_me bigint := public.current_private_user_id();
  v_row public.public_digital_invoices%rowtype;
  v_deadline date;
begin
  if auth.uid() is null or v_me is null then
    raise exception 'Not authenticated';
  end if;

  if p_deadline is not null and length(trim(p_deadline)) > 0 then
    begin
      v_deadline := left(trim(p_deadline), 10)::date;
    exception when others then
      v_deadline := (trim(p_deadline))::timestamptz::date;
    end;
  end if;

  insert into public.public_digital_invoices (
    status,
    amount,
    data,
    description,
    "senderName",
    "senderIsBusiness",
    deadline,
    "invoiceNo",
    "originalInvoiceNo",
    "referenceNo",
    "senderIban",
    category,
    "privateGroupId",
    "rawInvoiceId",
    "senderPrivateUserId",
    "isSeen",
    "viewCount",
    "claimCount",
    "externalPaymentCount"
  )
  values (
    coalesce(nullif(trim(p_status), ''), 'UNPAID'),
    coalesce(p_amount, 0),
    p_data,
    nullif(trim(p_description), ''),
    p_sender_name,
    coalesce(p_sender_is_business, false),
    v_deadline,
    p_invoice_no,
    p_original_invoice_no,
    p_reference_no,
    p_sender_iban,
    coalesce(p_category, ''),
    p_private_group_id,
    p_raw_invoice_id,
    v_me,
    false,
    0,
    0,
    0
  )
  returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

revoke all on function public.create_public_invoice(
  text, double precision, json, text, text, boolean, text, text, text, text, text, text, bigint, bigint
) from public, anon;

grant execute on function public.create_public_invoice(
  text, double precision, json, text, text, boolean, text, text, text, text, text, text, bigint, bigint
) to authenticated, service_role;
