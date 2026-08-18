-- Track last payment reminder so we can cooldown nudges
-- and run a daily due/overdue reminder job.

alter table public.digital_invoices
  add column if not exists "lastRemindedAt" timestamp with time zone;

create index if not exists digital_invoices_unpaid_deadline_idx
  on public.digital_invoices (deadline)
  where status = 'UNPAID';
