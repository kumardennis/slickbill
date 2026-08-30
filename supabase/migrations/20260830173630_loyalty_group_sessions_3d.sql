-- Step 3d: Group check-in sessions — 3-word session tokens, member tokens, join codes.

create table if not exists public.merchant_check_in_session_members (
  id bigint generated always as identity primary key,
  session_id bigint not null
    references public.merchant_check_in_sessions (id) on delete cascade,
  customer_private_user_id bigint not null
    references public.private_users (id) on delete cascade,
  member_token text not null,
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint merchant_check_in_session_members_session_customer_key
    unique (session_id, customer_private_user_id),
  constraint merchant_check_in_session_members_session_member_token_key
    unique (session_id, member_token)
);

create index if not exists merchant_check_in_session_members_customer_idx
  on public.merchant_check_in_session_members (customer_private_user_id, last_seen_at desc);

alter table public.merchant_check_in_session_members enable row level security;
revoke all on table public.merchant_check_in_session_members from public;
revoke all on table public.merchant_check_in_session_members from anon;
revoke all on table public.merchant_check_in_session_members from authenticated;
grant all on table public.merchant_check_in_session_members to service_role;

alter table public.merchant_check_in_sessions
  add column if not exists session_token text,
  add column if not exists join_code text;

create unique index if not exists merchant_check_in_sessions_join_code_key
  on public.merchant_check_in_sessions (join_code)
  where join_code is not null;

create unique index if not exists merchant_check_in_sessions_open_token_idx
  on public.merchant_check_in_sessions (merchant_private_user_id, session_token)
  where status = 'OPEN' and session_token is not null;

create or replace function public.loyalty_random_session_token(p_merchant_id bigint)
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  v_adjectives text[] := array[
    'Quick', 'Sly', 'Bold', 'Calm', 'Bright', 'Red', 'Blue', 'Green', 'Gold',
    'Silver', 'Swift', 'Warm', 'Cool', 'Fresh', 'Keen', 'Soft', 'Wild', 'Clear'
  ];
  v_nouns text[] := array[
    'Fox', 'Oak', 'Wave', 'Star', 'Moon', 'Lake', 'Peak', 'Cloud', 'River',
    'Stone', 'Leaf', 'Spark', 'Field', 'Bridge', 'Harbor', 'Cedar', 'Pine', 'Dune'
  ];
  v_token text;
  v_try integer := 0;
begin
  loop
    v_try := v_try + 1;
    v_token :=
      v_adjectives[1 + floor(random() * array_length(v_adjectives, 1))::integer]
      || v_nouns[1 + floor(random() * array_length(v_nouns, 1))::integer]
      || v_nouns[1 + floor(random() * array_length(v_nouns, 1))::integer];

    exit when not exists (
      select 1
      from public.merchant_check_in_sessions s
      where s.merchant_private_user_id = p_merchant_id
        and s.status = 'OPEN'
        and s.session_token = v_token
    );

    if v_try >= 40 then
      v_token := v_token || lpad(floor(random() * 100)::text, 2, '0');
      exit;
    end if;
  end loop;

  return v_token;
end;
$$;

create or replace function public.loyalty_random_member_token(p_session_id bigint)
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  v_adjectives text[] := array[
    'Sly', 'Red', 'Bold', 'Calm', 'Bright', 'Quick', 'Warm', 'Cool', 'Keen', 'Soft'
  ];
  v_nouns text[] := array[
    'Fox', 'Oak', 'Wave', 'Star', 'Moon', 'Lake', 'Peak', 'Cloud', 'River', 'Stone'
  ];
  v_token text;
  v_try integer := 0;
begin
  loop
    v_try := v_try + 1;
    v_token :=
      v_adjectives[1 + floor(random() * array_length(v_adjectives, 1))::integer]
      || v_nouns[1 + floor(random() * array_length(v_nouns, 1))::integer]
      || lpad(floor(random() * 100)::text, 2, '0');

    exit when not exists (
      select 1
      from public.merchant_check_in_session_members m
      where m.session_id = p_session_id
        and m.member_token = v_token
    );

    if v_try >= 40 then
      v_token := v_token || lpad(floor(random() * 10)::text, 1, '0');
      exit;
    end if;
  end loop;

  return v_token;
end;
$$;

create or replace function public.loyalty_new_join_code()
returns text
language sql
volatile
as $$
  select substr(replace(gen_random_uuid()::text, '-', ''), 1, 16);
$$;

create or replace function public.loyalty_touch_session_on_member_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.merchant_check_in_sessions s
  set opened_at = now()
  where s.id = new.session_id
    and s.status = 'OPEN';
  return new;
end;
$$;

drop trigger if exists trg_touch_session_on_member on public.merchant_check_in_session_members;

create trigger trg_touch_session_on_member
after insert or update of last_seen_at on public.merchant_check_in_session_members
for each row
execute function public.loyalty_touch_session_on_member_change();

-- Backfill v1 rows (one customer per session row).
do $$
declare
  v_row record;
  v_session_token text;
  v_member_token text;
  v_join_code text;
begin
  for v_row in
    select s.id, s.merchant_private_user_id, s.customer_private_user_id, s.opened_at
    from public.merchant_check_in_sessions s
    where s.customer_private_user_id is not null
      and not exists (
        select 1
        from public.merchant_check_in_session_members m
        where m.session_id = s.id
      )
  loop
    v_session_token := coalesce(
      (select s2.session_token from public.merchant_check_in_sessions s2 where s2.id = v_row.id),
      public.loyalty_random_session_token(v_row.merchant_private_user_id)
    );
    v_join_code := coalesce(
      (select s2.join_code from public.merchant_check_in_sessions s2 where s2.id = v_row.id),
      public.loyalty_new_join_code()
    );
    v_member_token := public.loyalty_random_member_token(v_row.id);

    update public.merchant_check_in_sessions
    set
      session_token = v_session_token,
      join_code = v_join_code
    where id = v_row.id;

    insert into public.merchant_check_in_session_members (
      session_id,
      customer_private_user_id,
      member_token,
      joined_at,
      last_seen_at
    ) values (
      v_row.id,
      v_row.customer_private_user_id,
      v_member_token,
      coalesce(v_row.opened_at, now()),
      coalesce(v_row.opened_at, now())
    );
  end loop;
end;
$$;

drop index if exists public.merchant_check_in_sessions_one_open_per_pair_idx;

alter table public.merchant_check_in_sessions
  drop column if exists customer_private_user_id;

create or replace function public.merchant_check_in(
  p_checkout_token text,
  p_join_code text default null
)
returns json
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_customer_id bigint;
  v_merchant_id bigint;
  v_session_id bigint;
  v_session_token text;
  v_member_token text;
  v_join_code text;
  v_checkout_token text;
  v_link public.merchant_customer_links%rowtype;
  v_member_count integer;
begin
  v_customer_id := public.current_private_user_id();
  if v_customer_id is null then
    raise exception 'Not authenticated';
  end if;

  v_checkout_token := trim(coalesce(p_checkout_token, ''));
  if v_checkout_token = '' then
    raise exception 'Invalid checkout token';
  end if;

  select q.merchant_private_user_id
    into v_merchant_id
  from public.merchant_checkout_qr q
  where q.checkout_token = v_checkout_token;

  if v_merchant_id is null then
    raise exception 'Unknown checkout QR';
  end if;

  if v_merchant_id = v_customer_id then
    raise exception 'Cannot check in to your own business QR';
  end if;

  if not exists (
    select 1
    from public.private_users pu
    where pu.id = v_merchant_id
      and pu."isBusiness" is true
  ) then
    raise exception 'Merchant is not a business account';
  end if;

  perform public.upsert_merchant_customer_check_in(v_merchant_id, v_customer_id);

  select *
    into v_link
  from public.merchant_customer_links l
  where l.merchant_private_user_id = v_merchant_id
    and l.customer_private_user_id = v_customer_id;

  -- Re-scan: return existing OPEN visit membership at this merchant.
  select
    s.id,
    s.session_token,
    s.join_code,
    m.member_token
  into
    v_session_id,
    v_session_token,
    v_join_code,
    v_member_token
  from public.merchant_check_in_session_members m
  inner join public.merchant_check_in_sessions s on s.id = m.session_id
  where m.customer_private_user_id = v_customer_id
    and s.merchant_private_user_id = v_merchant_id
    and s.status = 'OPEN'
  limit 1;

  if v_session_id is not null then
    update public.merchant_check_in_session_members
    set last_seen_at = now()
    where session_id = v_session_id
      and customer_private_user_id = v_customer_id;

    select count(*)::integer
      into v_member_count
    from public.merchant_check_in_session_members m
    where m.session_id = v_session_id;

    return json_build_object(
      'sessionId', v_session_id,
      'sessionToken', v_session_token,
      'memberToken', v_member_token,
      'joinCode', v_join_code,
      'joinUrl', 'https://app.slickbills.com/m/' || v_checkout_token || '/join/' || v_join_code,
      'status', 'OPEN',
      'memberCount', v_member_count,
      'loyaltyBadge', public.loyalty_badge_for_link(
        v_link.paid_invoice_count,
        v_link.last_paid_at,
        v_link.check_in_count,
        v_link.last_check_in_at
      ),
      'merchantPublicName', public.merchant_public_name(v_merchant_id),
      'checkInCount', v_link.check_in_count,
      'paidInvoiceCount', v_link.paid_invoice_count,
      'totalPaidEur', v_link.total_paid_eur,
      'lastActiveMonth', to_char(
        coalesce(v_link.last_paid_at, v_link.last_check_in_at) at time zone 'UTC',
        'YYYY-MM'
      )
    );
  end if;

  if p_join_code is not null and length(trim(p_join_code)) > 0 then
    select s.id, s.session_token, s.join_code
      into v_session_id, v_session_token, v_join_code
    from public.merchant_check_in_sessions s
    where s.merchant_private_user_id = v_merchant_id
      and s.status = 'OPEN'
      and s.join_code = trim(p_join_code);

    if v_session_id is null then
      raise exception 'Visit not found for join code';
    end if;

    v_member_token := public.loyalty_random_member_token(v_session_id);

    insert into public.merchant_check_in_session_members (
      session_id,
      customer_private_user_id,
      member_token
    ) values (
      v_session_id,
      v_customer_id,
      v_member_token
    );
  else
    v_session_token := public.loyalty_random_session_token(v_merchant_id);
    v_join_code := public.loyalty_new_join_code();
    v_member_token := null;

    insert into public.merchant_check_in_sessions (
      merchant_private_user_id,
      status,
      opened_at,
      session_token,
      join_code
    ) values (
      v_merchant_id,
      'OPEN',
      now(),
      v_session_token,
      v_join_code
    )
    returning id into v_session_id;

    v_member_token := public.loyalty_random_member_token(v_session_id);

    insert into public.merchant_check_in_session_members (
      session_id,
      customer_private_user_id,
      member_token
    ) values (
      v_session_id,
      v_customer_id,
      v_member_token
    );
  end if;

  select count(*)::integer
    into v_member_count
  from public.merchant_check_in_session_members m
  where m.session_id = v_session_id;

  return json_build_object(
    'sessionId', v_session_id,
    'sessionToken', v_session_token,
    'memberToken', v_member_token,
    'joinCode', v_join_code,
    'joinUrl', 'https://app.slickbills.com/m/' || v_checkout_token || '/join/' || v_join_code,
    'status', 'OPEN',
    'memberCount', v_member_count,
    'loyaltyBadge', public.loyalty_badge_for_link(
      v_link.paid_invoice_count,
      v_link.last_paid_at,
      v_link.check_in_count,
      v_link.last_check_in_at
    ),
    'merchantPublicName', public.merchant_public_name(v_merchant_id),
    'checkInCount', v_link.check_in_count,
    'paidInvoiceCount', v_link.paid_invoice_count,
    'totalPaidEur', v_link.total_paid_eur,
    'lastActiveMonth', to_char(
      coalesce(v_link.last_paid_at, v_link.last_check_in_at) at time zone 'UTC',
      'YYYY-MM'
    )
  );
end;
$$;

-- Replace overload; do not leave the 1-arg version (references dropped columns).
drop function if exists public.merchant_check_in(text);

revoke all on function public.merchant_check_in(text, text) from public;
grant execute on function public.merchant_check_in(text, text) to authenticated;
grant execute on function public.merchant_check_in(text, text) to service_role;

create or replace function public.customer_get_active_visit()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_customer_id bigint;
  v_checkout_token text;
begin
  v_customer_id := public.current_private_user_id();
  if v_customer_id is null then
    raise exception 'Not authenticated';
  end if;

  return (
    select json_build_object(
      'sessionId', s.id,
      'sessionToken', s.session_token,
      'memberToken', m.member_token,
      'joinCode', s.join_code,
      'joinUrl', 'https://app.slickbills.com/m/' || q.checkout_token || '/join/' || s.join_code,
      'merchantPublicName', public.merchant_public_name(s.merchant_private_user_id),
      'memberCount', (
        select count(*)::integer
        from public.merchant_check_in_session_members mm
        where mm.session_id = s.id
      ),
      'loyaltyBadge', public.loyalty_badge_for_link(
        l.paid_invoice_count,
        l.last_paid_at,
        l.check_in_count,
        l.last_check_in_at
      )
    )
    from public.merchant_check_in_session_members m
    inner join public.merchant_check_in_sessions s on s.id = m.session_id
    inner join public.merchant_checkout_qr q
      on q.merchant_private_user_id = s.merchant_private_user_id
    left join public.merchant_customer_links l
      on l.merchant_private_user_id = s.merchant_private_user_id
     and l.customer_private_user_id = m.customer_private_user_id
    where m.customer_private_user_id = v_customer_id
      and s.status = 'OPEN'
    order by m.last_seen_at desc
    limit 1
  );
end;
$$;

create or replace function public.merchant_list_open_sessions()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_merchant_id bigint;
begin
  v_merchant_id := public.assert_current_business_merchant();

  return coalesce((
    select json_agg(row_to_json(t) order by t.opened_at desc)
    from (
      select
        s.id as session_id,
        s.session_token,
        s.opened_at,
        (
          select count(*)::integer
          from public.merchant_check_in_session_members mm
          where mm.session_id = s.id
        ) as member_count,
        coalesce((
          select json_agg(row_to_json(mrow) order by mrow.joined_at asc)
          from (
            select
              mem.member_token,
              mem.joined_at,
              public.loyalty_badge_for_link(
                l.paid_invoice_count,
                l.last_paid_at,
                l.check_in_count,
                l.last_check_in_at
              ) as loyalty_badge,
              l.paid_invoice_count,
              l.check_in_count,
              l.total_paid_eur
            from public.merchant_check_in_session_members mem
            inner join public.merchant_customer_links l
              on l.merchant_private_user_id = s.merchant_private_user_id
             and l.customer_private_user_id = mem.customer_private_user_id
            where mem.session_id = s.id
          ) mrow
        ), '[]'::json) as members
      from public.merchant_check_in_sessions s
      where s.merchant_private_user_id = v_merchant_id
        and s.status = 'OPEN'
    ) t
  ), '[]'::json);
end;
$$;

revoke all on function public.customer_get_active_visit() from public;
grant execute on function public.customer_get_active_visit() to authenticated;
grant execute on function public.customer_get_active_visit() to service_role;

revoke all on function public.loyalty_random_session_token(bigint) from public;
revoke all on function public.loyalty_random_member_token(bigint) from public;
revoke all on function public.loyalty_new_join_code() from public;
grant execute on function public.loyalty_random_session_token(bigint) to service_role;
grant execute on function public.loyalty_random_member_token(bigint) to service_role;
grant execute on function public.loyalty_new_join_code() to service_role;
