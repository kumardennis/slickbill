-- Break RLS cycles that made login recurse:
--   users → private_users → public_digital_invoices ↔ public_invoice_claims
-- Cross-table checks go through SECURITY DEFINER helpers with row_security off.

create or replace function public.current_private_user_id()
returns bigint
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select pu.id
  from public.private_users pu
  inner join public.users u on u.id = pu."userId"
  where u."authUserId" = auth.uid()
  order by pu.id
  limit 1;
$$;

create or replace function public.is_invoice_counterparty_user(p_user_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.digital_invoices di
    join public.private_users pu
      on pu.id in (di."senderPrivateUserId", di."receiverPrivateUserId")
    where pu."userId" = p_user_id
      and (
        di."senderPrivateUserId" = public.current_private_user_id()
        or di."receiverPrivateUserId" = public.current_private_user_id()
      )
  );
$$;

create or replace function public.can_read_private_user(p_private_user_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    p_private_user_id = public.current_private_user_id()
    or exists (
      select 1
      from public.digital_invoices di
      where (
        di."senderPrivateUserId" = public.current_private_user_id()
        and di."receiverPrivateUserId" = p_private_user_id
      ) or (
        di."receiverPrivateUserId" = public.current_private_user_id()
        and di."senderPrivateUserId" = p_private_user_id
      )
    )
    or exists (
      select 1
      from public.public_digital_invoices p
      join public.public_invoice_claims c on c.public_invoice_id = p.id
      where p."senderPrivateUserId" = public.current_private_user_id()
        and c.claimed_by_user_id = p_private_user_id
    );
$$;

create or replace function public.is_my_app_user(p_user_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.users u
    where u.id = p_user_id
      and u."authUserId" = auth.uid()
  );
$$;

create or replace function public.can_read_public_invoice(p_invoice_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    exists (
      select 1
      from public.public_digital_invoices i
      where i.id = p_invoice_id
        and i."senderPrivateUserId" = public.current_private_user_id()
    )
    or exists (
      select 1
      from public.public_invoice_claims c
      where c.public_invoice_id = p_invoice_id
        and c.claimed_by_user_id = public.current_private_user_id()
    );
$$;

create or replace function public.can_read_public_claim(
  p_public_invoice_id bigint,
  p_claimed_by bigint
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    p_claimed_by = public.current_private_user_id()
    or exists (
      select 1
      from public.public_digital_invoices p
      where p.id = p_public_invoice_id
        and p."senderPrivateUserId" = public.current_private_user_id()
    );
$$;

revoke all on function public.is_invoice_counterparty_user(bigint) from public, anon;
revoke all on function public.can_read_private_user(bigint) from public, anon;
revoke all on function public.is_my_app_user(bigint) from public, anon;
revoke all on function public.can_read_public_invoice(bigint) from public, anon;
revoke all on function public.can_read_public_claim(bigint, bigint) from public, anon;

grant execute on function public.current_private_user_id() to authenticated, service_role;
grant execute on function public.is_invoice_counterparty_user(bigint) to authenticated, service_role;
grant execute on function public.can_read_private_user(bigint) to authenticated, service_role;
grant execute on function public.is_my_app_user(bigint) to authenticated, service_role;
grant execute on function public.can_read_public_invoice(bigint) to authenticated, service_role;
grant execute on function public.can_read_public_claim(bigint, bigint) to authenticated, service_role;

drop policy if exists users_select_own_or_invoice_party on public.users;
create policy users_select_own_or_invoice_party
on public.users for select to authenticated
using (
  "authUserId" = auth.uid()
  or public.is_invoice_counterparty_user(id)
);

drop policy if exists private_users_select_own_or_counterpart on public.private_users;
create policy private_users_select_own_or_counterpart
on public.private_users for select to authenticated
using (public.can_read_private_user(id));

drop policy if exists private_users_insert_own on public.private_users;
create policy private_users_insert_own
on public.private_users for insert to authenticated
with check (public.is_my_app_user("userId"));

drop policy if exists business_users_select_own_or_counterpart on public.business_users;
create policy business_users_select_own_or_counterpart
on public.business_users for select to authenticated
using (
  public.is_my_app_user("userId")
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

drop policy if exists business_users_write_own on public.business_users;
create policy business_users_write_own
on public.business_users for all to authenticated
using (public.is_my_app_user("userId"))
with check (public.is_my_app_user("userId"));

drop policy if exists public_invoices_select_owner_or_claimer on public.public_digital_invoices;
create policy public_invoices_select_owner_or_claimer
on public.public_digital_invoices for select to authenticated
using (public.can_read_public_invoice(id));

drop policy if exists public_claims_select_owner_or_claimer on public.public_invoice_claims;
create policy public_claims_select_owner_or_claimer
on public.public_invoice_claims for select to authenticated
using (public.can_read_public_claim(public_invoice_id, claimed_by_user_id));

drop policy if exists public_claims_delete_own on public.public_invoice_claims;
create policy public_claims_delete_own
on public.public_invoice_claims for delete to authenticated
using (public.can_read_public_claim(public_invoice_id, claimed_by_user_id));
