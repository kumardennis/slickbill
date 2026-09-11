-- Lock core tables so the anon key cannot read/write other people's data.
-- Public bill links go through security-definer RPCs by token.

-- ---------------------------------------------------------------------------
-- Helpers / RPCs
-- ---------------------------------------------------------------------------

create or replace function public.get_public_invoice_by_token(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice jsonb;
  v_sender jsonb;
begin
  if p_token is null or length(trim(p_token)) = 0 then
    return null;
  end if;

  select to_jsonb(i) into v_invoice
  from public.public_digital_invoices i
  where i."publicToken" = trim(p_token)
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

revoke all on function public.get_public_invoice_by_token(text) from public;
grant execute on function public.get_public_invoice_by_token(text) to anon, authenticated, service_role;

create or replace function public.increment_public_invoice_view(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_token is null or length(trim(p_token)) = 0 then
    return;
  end if;

  update public.public_digital_invoices
  set "viewCount" = coalesce("viewCount", 0) + 1
  where "publicToken" = trim(p_token);
end;
$$;

revoke all on function public.increment_public_invoice_view(text) from public;
grant execute on function public.increment_public_invoice_view(text) to anon, authenticated, service_role;

create or replace function public.increment_public_invoice_claim(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_invoice_id is null then
    return;
  end if;

  update public.public_digital_invoices
  set
    "viewCount" = coalesce("viewCount", 0) + 1,
    "claimCount" = coalesce("claimCount", 0) + 1
  where id = p_invoice_id;
end;
$$;

revoke all on function public.increment_public_invoice_claim(bigint) from public;
grant execute on function public.increment_public_invoice_claim(bigint) to authenticated, service_role;

create or replace function public.claim_fcm_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_token is null or length(trim(p_token)) = 0 then
    update public.users
    set fcm_token = null
    where "authUserId" = auth.uid();
    return;
  end if;

  update public.users
  set fcm_token = null
  where fcm_token = trim(p_token)
    and "authUserId" is distinct from auth.uid();

  update public.users
  set fcm_token = trim(p_token)
  where "authUserId" = auth.uid();
end;
$$;

revoke all on function public.claim_fcm_token(text) from public;
grant execute on function public.claim_fcm_token(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Drop open policies
-- ---------------------------------------------------------------------------

drop policy if exists "Enable insert for authenticated users only" on public.users;
drop policy if exists "Enable insert for authenticated users only" on public.private_users;
drop policy if exists "Enable insert for authenticated users only" on public.business_users;
drop policy if exists "Enable insert for authenticated users only" on public.digital_invoices;
drop policy if exists "Enable insert for authenticated users only" on public.senders;
drop policy if exists "Enable insert for authenticated users only" on public.receivers;
drop policy if exists "Enable insert for authenticated users only" on public.private_groups;
drop policy if exists "Enable insert for authenticated users only" on public.public_digital_invoices;
drop policy if exists "Enable read access for all users" on public.public_digital_invoices;
drop policy if exists "Enable update access for all users" on public.public_digital_invoices;
drop policy if exists "Enable insert for authenticated users only" on public.public_invoice_claims;
drop policy if exists "Enable read access for all users" on public.tickets;
drop policy if exists "Enable insert for authenticated users only" on public.user_devices;
drop policy if exists "Enable read access for all users" on public.user_devices;

-- ---------------------------------------------------------------------------
-- Revoke anon from private tables (RPCs remain granted above)
-- ---------------------------------------------------------------------------

revoke all on table public.users from anon;
revoke all on table public.private_users from anon;
revoke all on table public.business_users from anon;
revoke all on table public.digital_invoices from anon;
revoke all on table public.senders from anon;
revoke all on table public.receivers from anon;
revoke all on table public.private_groups from anon;
revoke all on table public.private_groups_users from anon;
revoke all on table public.public_digital_invoices from anon;
revoke all on table public.public_invoice_claims from anon;
revoke all on table public.tickets from anon;
revoke all on table public.user_devices from anon;
revoke all on table public.raw_invoices from anon;
revoke all on table public.payments from anon;

revoke all on table public.raw_invoices from authenticated;

-- ---------------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------------

create policy users_select_own_or_invoice_party
on public.users for select to authenticated
using (
  "authUserId" = auth.uid()
  or exists (
    select 1
    from public.digital_invoices di
    join public.private_users pu
      on pu.id in (di."senderPrivateUserId", di."receiverPrivateUserId")
    where pu."userId" = users.id
      and (
        di."senderPrivateUserId" = public.current_private_user_id()
        or di."receiverPrivateUserId" = public.current_private_user_id()
      )
  )
);

create policy users_insert_own
on public.users for insert to authenticated
with check ("authUserId" = auth.uid());

create policy users_update_own
on public.users for update to authenticated
using ("authUserId" = auth.uid())
with check ("authUserId" = auth.uid());

-- ---------------------------------------------------------------------------
-- private_users
-- ---------------------------------------------------------------------------

create policy private_users_select_own_or_counterpart
on public.private_users for select to authenticated
using (
  id = public.current_private_user_id()
  or exists (
    select 1
    from public.digital_invoices di
    where (
      di."senderPrivateUserId" = public.current_private_user_id()
      and di."receiverPrivateUserId" = private_users.id
    ) or (
      di."receiverPrivateUserId" = public.current_private_user_id()
      and di."senderPrivateUserId" = private_users.id
    )
  )
  or exists (
    select 1
    from public.public_digital_invoices p
    join public.public_invoice_claims c on c.public_invoice_id = p.id
    where p."senderPrivateUserId" = public.current_private_user_id()
      and c.claimed_by_user_id = private_users.id
  )
);

create policy private_users_insert_own
on public.private_users for insert to authenticated
with check (
  exists (
    select 1 from public.users u
    where u.id = private_users."userId"
      and u."authUserId" = auth.uid()
  )
);

create policy private_users_update_own
on public.private_users for update to authenticated
using (id = public.current_private_user_id())
with check (id = public.current_private_user_id());

-- ---------------------------------------------------------------------------
-- business_users
-- ---------------------------------------------------------------------------

create policy business_users_select_own_or_counterpart
on public.business_users for select to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = business_users."userId"
      and u."authUserId" = auth.uid()
  )
  or exists (
    select 1
    from public.digital_invoices di
    join public.receivers r on r.id = di."receiverId"
    where r."businessUserId" = business_users.id
      and (
        di."senderPrivateUserId" = public.current_private_user_id()
        or di."receiverPrivateUserId" = public.current_private_user_id()
      )
  )
);

create policy business_users_write_own
on public.business_users for all to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = business_users."userId"
      and u."authUserId" = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.users u
    where u.id = business_users."userId"
      and u."authUserId" = auth.uid()
  )
);

-- ---------------------------------------------------------------------------
-- digital_invoices
-- ---------------------------------------------------------------------------

create policy digital_invoices_select_party
on public.digital_invoices for select to authenticated
using (
  "senderPrivateUserId" = public.current_private_user_id()
  or "receiverPrivateUserId" = public.current_private_user_id()
);

create policy digital_invoices_insert_party
on public.digital_invoices for insert to authenticated
with check (
  "senderPrivateUserId" = public.current_private_user_id()
  or "receiverPrivateUserId" = public.current_private_user_id()
);

create policy digital_invoices_update_party
on public.digital_invoices for update to authenticated
using (
  "senderPrivateUserId" = public.current_private_user_id()
  or "receiverPrivateUserId" = public.current_private_user_id()
)
with check (
  "senderPrivateUserId" = public.current_private_user_id()
  or "receiverPrivateUserId" = public.current_private_user_id()
);

create policy digital_invoices_delete_party
on public.digital_invoices for delete to authenticated
using (
  "senderPrivateUserId" = public.current_private_user_id()
  or "receiverPrivateUserId" = public.current_private_user_id()
);

-- ---------------------------------------------------------------------------
-- senders / receivers (claim inserts a sender row for the original issuer)
-- ---------------------------------------------------------------------------

create policy senders_select_related
on public.senders for select to authenticated
using (
  "privateUserId" = public.current_private_user_id()
  or exists (
    select 1 from public.digital_invoices di
    where di."senderId" = senders.id
      and (
        di."senderPrivateUserId" = public.current_private_user_id()
        or di."receiverPrivateUserId" = public.current_private_user_id()
      )
  )
);

create policy senders_insert_authenticated
on public.senders for insert to authenticated
with check (true);

create policy receivers_select_related
on public.receivers for select to authenticated
using (
  "privateUserId" = public.current_private_user_id()
  or exists (
    select 1 from public.digital_invoices di
    where di."receiverId" = receivers.id
      and (
        di."senderPrivateUserId" = public.current_private_user_id()
        or di."receiverPrivateUserId" = public.current_private_user_id()
      )
  )
);

create policy receivers_insert_authenticated
on public.receivers for insert to authenticated
with check (true);

-- ---------------------------------------------------------------------------
-- public invoices (no anon table access; guests use RPCs)
-- ---------------------------------------------------------------------------

create policy public_invoices_select_owner_or_claimer
on public.public_digital_invoices for select to authenticated
using (
  "senderPrivateUserId" = public.current_private_user_id()
  or exists (
    select 1 from public.public_invoice_claims c
    where c.public_invoice_id = public_digital_invoices.id
      and c.claimed_by_user_id = public.current_private_user_id()
  )
);

create policy public_invoices_insert_own
on public.public_digital_invoices for insert to authenticated
with check ("senderPrivateUserId" = public.current_private_user_id());

create policy public_invoices_update_own
on public.public_digital_invoices for update to authenticated
using ("senderPrivateUserId" = public.current_private_user_id())
with check ("senderPrivateUserId" = public.current_private_user_id());

create policy public_invoices_delete_own
on public.public_digital_invoices for delete to authenticated
using ("senderPrivateUserId" = public.current_private_user_id());

create policy public_claims_select_owner_or_claimer
on public.public_invoice_claims for select to authenticated
using (
  claimed_by_user_id = public.current_private_user_id()
  or exists (
    select 1 from public.public_digital_invoices p
    where p.id = public_invoice_claims.public_invoice_id
      and p."senderPrivateUserId" = public.current_private_user_id()
  )
);

create policy public_claims_insert_own
on public.public_invoice_claims for insert to authenticated
with check (claimed_by_user_id = public.current_private_user_id());

create policy public_claims_delete_own
on public.public_invoice_claims for delete to authenticated
using (
  claimed_by_user_id = public.current_private_user_id()
  or exists (
    select 1 from public.public_digital_invoices p
    where p.id = public_invoice_claims.public_invoice_id
      and p."senderPrivateUserId" = public.current_private_user_id()
  )
);

-- ---------------------------------------------------------------------------
-- groups, tickets, devices, payments
-- ---------------------------------------------------------------------------

create policy private_groups_own
on public.private_groups for all to authenticated
using ("creatorUserId" = public.current_private_user_id())
with check ("creatorUserId" = public.current_private_user_id());

create policy private_groups_users_member
on public.private_groups_users for all to authenticated
using (
  "privateUserId" = public.current_private_user_id()
  or exists (
    select 1 from public.private_groups g
    where g.id = private_groups_users."orivateGroupId"
      and g."creatorUserId" = public.current_private_user_id()
  )
)
with check (
  "privateUserId" = public.current_private_user_id()
  or exists (
    select 1 from public.private_groups g
    where g.id = private_groups_users."orivateGroupId"
      and g."creatorUserId" = public.current_private_user_id()
  )
);

create policy tickets_own
on public.tickets for all to authenticated
using ("privateUserId" = public.current_private_user_id())
with check ("privateUserId" = public.current_private_user_id());

create policy user_devices_own
on public.user_devices for all to authenticated
using (
  user_id in (select id from public.users where "authUserId" = auth.uid())
)
with check (
  user_id in (select id from public.users where "authUserId" = auth.uid())
);

create policy payments_via_invoice
on public.payments for all to authenticated
using (
  exists (
    select 1 from public.digital_invoices di
    where di.id = payments."digitalInvoiceId"
      and (
        di."senderPrivateUserId" = public.current_private_user_id()
        or di."receiverPrivateUserId" = public.current_private_user_id()
      )
  )
)
with check (
  exists (
    select 1 from public.digital_invoices di
    where di.id = payments."digitalInvoiceId"
      and (
        di."senderPrivateUserId" = public.current_private_user_id()
        or di."receiverPrivateUserId" = public.current_private_user_id()
      )
  )
);
