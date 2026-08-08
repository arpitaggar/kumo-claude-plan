-- =============================================================================
-- Stage 27 — Per-trip masked email alias (inbound forwarding, no inbox)
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================
--
-- Gives every itinerary a single generated email address (e.g.
-- trip-x7k2m9qz@<trip_email_domain>) that members can hand to airlines,
-- hotels, event organisers, etc. instead of a personal inbox. Kumo never
-- exposes an inbox for it — the `inbound-trip-email` Edge Function (see
-- supabase/functions/) receives mail sent to it from whichever inbound-email
-- provider is configured, looks up the trip by alias, and re-sends the
-- message to every member's real address via Resend, behaving like a
-- distribution list. No message body is ever persisted —
-- trip_email_forward_log below stores metadata only (sender, subject,
-- timestamp), for rate-limiting and support debugging.
--
-- Requires manual, non-code setup before this actually receives mail —
-- see supabase/functions/inbound-trip-email/index.ts's header comment for
-- the full list (a domain you control DNS for, an inbound-email provider
-- pointed at it, and two secrets). None of that blocks this migration or
-- the rest of the app; the alias just won't receive real mail until it's
-- done.
-- =============================================================================

-- Placeholder until a real domain is live — see this migration's header.
insert into public.app_config (key, value)
values ('trip_email_domain', 'trips.example.com')
on conflict (key) do nothing;

create table if not exists public.trip_email_aliases (
  id             uuid        primary key default gen_random_uuid(),
  itinerary_id   uuid        not null unique references public.itineraries(id) on delete cascade,
  local_part     text        not null unique,
  created_at     timestamptz not null default now()
);

comment on column public.trip_email_aliases.local_part is
  'The part before @ — combined client-side (and in inbound-trip-email) with '
  'app_config.trip_email_domain to form the full address. Stored separately '
  'so the domain can change later (e.g. once real DNS is live) without '
  'rewriting every trip''s alias.';

alter table public.trip_email_aliases enable row level security;

drop policy if exists "trip_email_aliases_member_select" on public.trip_email_aliases;

create policy "trip_email_aliases_member_select" on public.trip_email_aliases
  for select using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where m->>'user_id' = auth.uid()::text
               or m->>'userId'  = auth.uid()::text
          )
        )
    )
  );

-- No insert/update/delete policy for authenticated/anon — rows are only
-- written by generate_trip_email_alias() (SECURITY DEFINER, below, itself
-- only reachable via the on-insert trigger below or a direct RPC call) or
-- the service role.

-- ─── Alias generation ────────────────────────────────────────────────────────
-- 10 random lowercase letters/digits (0/1/l/o dropped to avoid look-alike
-- confusion when read aloud to a booking agent), prefixed "trip-". Short
-- enough to read over a phone call, random enough not to be guessable.
-- Idempotent — returns the existing row if the trip already has one, so
-- it's safe to call from both the insert trigger and the backfill below.
create or replace function public.generate_trip_email_alias(p_itinerary_id uuid)
returns public.trip_email_aliases
language plpgsql
security definer
set search_path = public
as $$
declare
  _alphabet   text := 'abcdefghjkmnpqrstuvwxyz23456789';
  _local_part text;
  _row        public.trip_email_aliases;
  _attempt    int := 0;
begin
  select * into _row from public.trip_email_aliases where itinerary_id = p_itinerary_id;
  if found then
    return _row;
  end if;

  loop
    _attempt := _attempt + 1;

    select 'trip-' || string_agg(
             substr(_alphabet, (random() * length(_alphabet))::int + 1, 1), ''
           )
      into _local_part
      from generate_series(1, 10);

    begin
      insert into public.trip_email_aliases (itinerary_id, local_part)
      values (p_itinerary_id, _local_part)
      returning * into _row;
      return _row;
    exception when unique_violation then
      if _attempt >= 5 then
        raise;
      end if;
    end;
  end loop;
end;
$$;

grant execute on function public.generate_trip_email_alias(uuid) to authenticated;

create or replace function public.handle_new_itinerary_email_alias()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.generate_trip_email_alias(new.id);
  return new;
end;
$$;

drop trigger if exists on_itinerary_created_email_alias on public.itineraries;
create trigger on_itinerary_created_email_alias
  after insert on public.itineraries
  for each row execute function public.handle_new_itinerary_email_alias();

-- Backfill trips created before this migration.
do $$
declare
  _itinerary record;
begin
  for _itinerary in select id from public.itineraries loop
    perform public.generate_trip_email_alias(_itinerary.id);
  end loop;
end $$;

-- ─── Forward audit log (metadata only — no message body is ever stored) ─────
create table if not exists public.trip_email_forward_log (
  id            uuid        primary key default gen_random_uuid(),
  itinerary_id  uuid        not null references public.itineraries(id) on delete cascade,
  from_address  text        not null,
  subject       text,
  forwarded_to  int         not null, -- member count the message was fanned out to
  created_at    timestamptz not null default now()
);

create index if not exists trip_email_forward_log_itinerary_id_idx
  on public.trip_email_forward_log (itinerary_id, created_at desc);

alter table public.trip_email_forward_log enable row level security;

drop policy if exists "trip_email_forward_log_member_select" on public.trip_email_forward_log;

create policy "trip_email_forward_log_member_select" on public.trip_email_forward_log
  for select using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where m->>'user_id' = auth.uid()::text
               or m->>'userId'  = auth.uid()::text
          )
        )
    )
  );

-- No write policy — only the inbound-trip-email Edge Function (service
-- role) writes here.
