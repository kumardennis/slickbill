-- Repo parity: externalPaymentCount for public invoice external-bank settlements.
-- Safe if column already exists in the remote project.
alter table public.public_digital_invoices
  add column if not exists "externalPaymentCount" integer not null default 0;
