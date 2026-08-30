-- Realtime pings for merchant cashier (no customer ids on the wire).
-- Sessions table stays RPC-only; this table is a safe notification fan-out.

create table if not exists public.merchant_cashier_events (
  id bigint generated always as identity primary key,
  merchant_private_user_id bigint not null
    references public.private_users (id) on delete cascade,
  session_id bigint not null,
  event_type text not null,
  created_at timestamptz not null default now(),
  constraint merchant_cashier_events_event_type_check
    check (event_type in ('session_opened', 'session_updated', 'session_closed'))
);

create index if not exists merchant_cashier_events_merchant_created_idx
  on public.merchant_cashier_events (merchant_private_user_id, created_at desc);

alter table public.merchant_cashier_events enable row level security;

revoke all on table public.merchant_cashier_events from public;
revoke all on table public.merchant_cashier_events from anon;
grant select on table public.merchant_cashier_events to authenticated;
grant all on table public.merchant_cashier_events to service_role;

create policy merchant_cashier_events_select_own
  on public.merchant_cashier_events
  for select
  to authenticated
  using (
    merchant_private_user_id = public.current_private_user_id()
    and exists (
      select 1
      from public.private_users pu
      where pu.id = public.current_private_user_id()
        and pu."isBusiness" is true
    )
  );

create or replace function public.notify_merchant_cashier_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.status = 'OPEN' then
    insert into public.merchant_cashier_events (
      merchant_private_user_id,
      session_id,
      event_type
    ) values (
      new.merchant_private_user_id,
      new.id,
      'session_opened'
    );
  elsif tg_op = 'UPDATE' then
    if old.status = 'OPEN' and new.status = 'CLOSED' then
      insert into public.merchant_cashier_events (
        merchant_private_user_id,
        session_id,
        event_type
      ) values (
        new.merchant_private_user_id,
        new.id,
        'session_closed'
      );
    elsif new.status = 'OPEN' then
      insert into public.merchant_cashier_events (
        merchant_private_user_id,
        session_id,
        event_type
      ) values (
        new.merchant_private_user_id,
        new.id,
        'session_updated'
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_merchant_cashier_event on public.merchant_check_in_sessions;

create trigger trg_merchant_cashier_event
after insert or update of status, opened_at on public.merchant_check_in_sessions
for each row
execute function public.notify_merchant_cashier_event();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.merchant_cashier_events;
  end if;
exception
  when duplicate_object then
    null;
end;
$$;

revoke all on function public.notify_merchant_cashier_event() from public;
grant execute on function public.notify_merchant_cashier_event() to service_role;
