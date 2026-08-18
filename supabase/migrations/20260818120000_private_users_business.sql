-- Business identity lives on private_users (the operational account).
-- isBusiness + publicName are a label on that row, not a second party type.

alter table public.private_users
  add column if not exists "isBusiness" boolean not null default false,
  add column if not exists "publicName" text;
