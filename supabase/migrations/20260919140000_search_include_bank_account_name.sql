-- Keep bankAccountName in invoice search. Matching stays strict
-- (substring or trigram > 0.45), so "testing" does not match "Test Testson".

create or replace function public.search_my_digital_invoice_ids(
  p_side text,
  p_q text
)
returns table(id bigint)
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_me bigint := public.current_private_user_id();
  v_q text;
begin
  if auth.uid() is null or v_me is null then
    raise exception 'Not authenticated';
  end if;

  v_q := btrim(regexp_replace(coalesce(p_q, ''), '[%_,]+', ' ', 'g'));
  v_q := btrim(regexp_replace(v_q, '\s+', ' ', 'g'));
  if v_q = '' then
    return;
  end if;

  if p_side = 'received' then
    return query
    select di.id
    from public.digital_invoices di
    left join public.private_users spu
      on spu.id = di."senderPrivateUserId"
    where di."receiverPrivateUserId" = v_me
      and coalesce(di."isObsolete", false) = false
      and (
        public.invoice_text_matches(di.description, v_q)
        or public.invoice_text_matches(di."senderName", v_q)
        or public.invoice_text_matches(spu."publicName", v_q)
        or public.invoice_text_matches(spu."bankAccountName", v_q)
        or public.invoice_text_matches(
          concat_ws(' ', spu."firstName", spu."lastName"),
          v_q
        )
      );
  elsif p_side = 'sent' then
    return query
    select di.id
    from public.digital_invoices di
    left join public.receivers r on r.id = di."receiverId"
    left join public.private_users rpu
      on rpu.id = coalesce(r."privateUserId", di."receiverPrivateUserId")
    left join public.business_users bu on bu.id = r."businessUserId"
    where di."senderPrivateUserId" = v_me
      and coalesce(di."isObsolete", false) = false
      and (
        public.invoice_text_matches(di.description, v_q)
        or public.invoice_text_matches(
          concat_ws(' ', rpu."firstName", rpu."lastName"),
          v_q
        )
        or public.invoice_text_matches(rpu."publicName", v_q)
        or public.invoice_text_matches(rpu."bankAccountName", v_q)
        or public.invoice_text_matches(bu."publicName", v_q)
        or public.invoice_text_matches(bu."fullName", v_q)
      );
  else
    raise exception 'Invalid side';
  end if;
end;
$$;
