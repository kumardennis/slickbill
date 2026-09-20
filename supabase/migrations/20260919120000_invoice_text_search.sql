-- Fuzzy search for invoice lists: description + counterparty name.
-- Substring (ILIKE) plus pg_trgm similarity for typos.

create extension if not exists pg_trgm;

create index if not exists digital_invoices_description_trgm
  on public.digital_invoices using gin (description gin_trgm_ops);

create index if not exists digital_invoices_sender_name_trgm
  on public.digital_invoices using gin ("senderName" gin_trgm_ops);

create index if not exists public_digital_invoices_description_trgm
  on public.public_digital_invoices using gin (description gin_trgm_ops);

create or replace function public.invoice_text_matches(p_haystack text, p_q text)
returns boolean
language sql
immutable
parallel safe
as $$
  select
    case
      when p_q is null or length(btrim(p_q)) = 0 then true
      when coalesce(p_haystack, '') ilike ('%' || p_q || '%') then true
      when length(btrim(p_q)) >= 3
        and similarity(lower(coalesce(p_haystack, '')), lower(p_q)) > 0.25
        then true
      else false
    end;
$$;

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

revoke all on function public.invoice_text_matches(text, text) from public;
grant execute on function public.invoice_text_matches(text, text)
  to authenticated, service_role;

revoke all on function public.search_my_digital_invoice_ids(text, text) from public;
grant execute on function public.search_my_digital_invoice_ids(text, text)
  to authenticated, service_role;
