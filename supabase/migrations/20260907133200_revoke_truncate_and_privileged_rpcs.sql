-- TRUNCATE is not subject to RLS; authenticated must not be able to wipe tables.
-- Also drop leftover EXECUTE grants to anon on privileged RPCs.

revoke truncate, trigger on table
  public.users,
  public.private_users,
  public.business_users,
  public.digital_invoices,
  public.senders,
  public.receivers,
  public.private_groups,
  public.private_groups_users,
  public.public_digital_invoices,
  public.public_invoice_claims,
  public.tickets,
  public.user_devices,
  public.payments
from authenticated;

revoke all on function public.claim_fcm_token(text) from public, anon;
grant execute on function public.claim_fcm_token(text) to authenticated, service_role;

revoke all on function public.increment_public_invoice_claim(bigint) from public, anon;
grant execute on function public.increment_public_invoice_claim(bigint) to authenticated, service_role;

revoke all on function public.get_public_invoice_by_token(text) from public;
grant execute on function public.get_public_invoice_by_token(text) to anon, authenticated, service_role;

revoke all on function public.increment_public_invoice_view(text) from public;
grant execute on function public.increment_public_invoice_view(text) to anon, authenticated, service_role;
