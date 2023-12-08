create table "public"."private_groups" (
    "id" bigint generated by default as identity not null,
    "created_at" timestamp with time zone default now(),
    "creatorUserId" bigint,
    "deadline" date,
    "description" character varying
);


alter table "public"."private_groups" enable row level security;

create table "public"."private_groups_users" (
    "id" bigint generated by default as identity not null,
    "created_at" timestamp with time zone default now(),
    "privateUserId" bigint,
    "orivateGroupId" bigint
);


alter table "public"."private_groups_users" enable row level security;

alter table "public"."digital_invoices" add column "category" text default ''::text;

alter table "public"."digital_invoices" add column "privateGroupId" bigint;

CREATE UNIQUE INDEX private_groups_pkey ON public.private_groups USING btree (id);

CREATE UNIQUE INDEX private_groups_users_pkey ON public.private_groups_users USING btree (id);

alter table "public"."private_groups" add constraint "private_groups_pkey" PRIMARY KEY using index "private_groups_pkey";

alter table "public"."private_groups_users" add constraint "private_groups_users_pkey" PRIMARY KEY using index "private_groups_users_pkey";

alter table "public"."digital_invoices" add constraint "digital_invoices_privateGroupId_fkey" FOREIGN KEY ("privateGroupId") REFERENCES private_groups(id) not valid;

alter table "public"."digital_invoices" validate constraint "digital_invoices_privateGroupId_fkey";

alter table "public"."private_groups" add constraint "private_groups_creatorUserId_fkey" FOREIGN KEY ("creatorUserId") REFERENCES private_users(id) not valid;

alter table "public"."private_groups" validate constraint "private_groups_creatorUserId_fkey";

alter table "public"."private_groups_users" add constraint "private_groups_users_orivateGroupId_fkey" FOREIGN KEY ("orivateGroupId") REFERENCES private_groups(id) not valid;

alter table "public"."private_groups_users" validate constraint "private_groups_users_orivateGroupId_fkey";

alter table "public"."private_groups_users" add constraint "private_groups_users_privateUserId_fkey" FOREIGN KEY ("privateUserId") REFERENCES private_users(id) not valid;

alter table "public"."private_groups_users" validate constraint "private_groups_users_privateUserId_fkey";

create policy "Enable insert for authenticated users only"
on "public"."private_groups"
as permissive
for all
to authenticated, anon
using (true)
with check (true);



