-- Snapshot business identity on the invoice at send time.
-- Changing private_users.isBusiness later must not rewrite past bills.

alter table public.digital_invoices
  add column if not exists "senderIsBusiness" boolean not null default false;

alter table public.public_digital_invoices
  add column if not exists "senderIsBusiness" boolean not null default false;
