-- Dedup deposit / order FCM so Alchemy + Monerium webhooks do not double-notify.

create table if not exists public.monerium_notified_orders (
  "orderId" text primary key,
  "privateUserId" text,
  kind text,
  "notifiedAt" timestamp with time zone not null default now()
);

alter table public.monerium_notified_orders enable row level security;

revoke all on table public.monerium_notified_orders from anon, authenticated, public;
grant all on table public.monerium_notified_orders to service_role;
