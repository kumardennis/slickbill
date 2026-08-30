-- Notify customers when their visit ends so the app bar clears codenames.

create table if not exists public.customer_visit_events (
  id bigint generated always as identity primary key,
  customer_private_user_id bigint not null
    references public.private_users (id) on delete cascade,
  session_id bigint not null,
  event_type text not null,
  created_at timestamptz not null default now(),
  constraint customer_visit_events_event_type_check
    check (event_type in ('session_closed'))
);

create index if not exists customer_visit_events_customer_created_idx
  on public.customer_visit_events (customer_private_user_id, created_at desc);

alter table public.customer_visit_events enable row level security;

revoke all on table public.customer_visit_events from public;
revoke all on table public.customer_visit_events from anon;
grant select on table public.customer_visit_events to authenticated;
grant all on table public.customer_visit_events to service_role;

drop policy if exists customer_visit_events_select_own
  on public.customer_visit_events;

create policy customer_visit_events_select_own
  on public.customer_visit_events
  for select
  to authenticated
  using (customer_private_user_id = public.current_private_user_id());

create or replace function public.notify_customer_visit_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and old.status = 'OPEN'
     and new.status = 'CLOSED' then
    insert into public.customer_visit_events (
      customer_private_user_id,
      session_id,
      event_type
    )
    select
      m.customer_private_user_id,
      new.id,
      'session_closed'
    from public.merchant_check_in_session_members m
    where m.session_id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_customer_visit_event on public.merchant_check_in_sessions;

create trigger trg_customer_visit_event
after update of status on public.merchant_check_in_sessions
for each row
execute function public.notify_customer_visit_event();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.customer_visit_events;
  end if;
exception
  when duplicate_object then
    null;
end;
$$;

revoke all on function public.notify_customer_visit_event() from public;
grant execute on function public.notify_customer_visit_event() to service_role;
