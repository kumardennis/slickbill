-- Fix checkout QR scan: remove stale 1-arg merchant_check_in after group sessions (3d).
-- PostgREST was calling the old overload (references dropped customer_private_user_id).

drop function if exists public.merchant_check_in(text);

revoke all on function public.merchant_check_in(text, text) from public;
grant execute on function public.merchant_check_in(text, text) to authenticated;
grant execute on function public.merchant_check_in(text, text) to service_role;
