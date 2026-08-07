-- Monerium server-side settlement support
-- Persist OAuth/SIWE tokens for unattended GET /orders?txHash=

create table if not exists "public"."monerium_tokens" (
  "privateUserId" text primary key,
  "accessToken" text not null,
  "refreshToken" text,
  "tokenType" text default 'Bearer',
  "scope" text,
  "expiresAt" timestamp with time zone not null,
  "walletAddress" text,
  "updatedAt" timestamp with time zone default now()
);

create index if not exists monerium_tokens_wallet_address_idx
  on "public"."monerium_tokens" ("walletAddress");

alter table "public"."monerium_tokens" enable row level security;

-- Service role only (Express settlement); no anon/authenticated policies by default
grant all on table "public"."monerium_tokens" to "service_role";
grant select, insert, update, delete on table "public"."monerium_tokens" to "service_role";
