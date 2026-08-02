-- =============================================================================
-- Stage 21 — Trip route segments (transport legs) + premium feature flags
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. trip_segments table
--    An ordered sequence of transport legs (flight/train/bus/car/motorcycle/
--    ferry/walk/other) per itinerary. Origin/destination are denormalised
--    (name + lat/lng) on each row rather than referencing a shared waypoints
--    table — editing one segment's destination does NOT retroactively update
--    the next segment's origin; "continuity" is a UI convenience only.
-- -----------------------------------------------------------------------------

create table if not exists public.trip_segments (
  id                uuid        primary key default gen_random_uuid(),
  itinerary_id      uuid        not null references public.itineraries(id) on delete cascade,
  order_index       int         not null,
  transport_mode    text        not null
                                check (transport_mode in
                                  ('flight','train','bus','car','motorcycle','ferry','walk','other')),
  origin_name       text        not null,
  origin_lat        double precision not null,
  origin_lng        double precision not null,
  destination_name  text        not null,
  destination_lat   double precision not null,
  destination_lng   double precision not null,
  departure_time    timestamptz,
  arrival_time      timestamptz,
  notes             text,
  created_at        timestamptz not null default now()
);

create index if not exists trip_segments_itinerary_id_idx
  on public.trip_segments (itinerary_id, order_index);

-- -----------------------------------------------------------------------------
-- 2. Row Level Security
--    Segments are shared trip content (like the itinerary row itself), so
--    write access follows the same "owner or editor member" rule used for
--    itineraries_member_update (stage1), not the "creator only" rule used for
--    expenses/packing. Uses the stage13 EXISTS + jsonb_array_elements pattern
--    so both trigger-written (userId) and Flutter-written (user_id) member
--    key casings are accepted.
-- -----------------------------------------------------------------------------

alter table public.trip_segments enable row level security;

drop policy if exists "trip_segments_member_select" on public.trip_segments;
drop policy if exists "trip_segments_editor_write"  on public.trip_segments;

create policy "trip_segments_member_select" on public.trip_segments
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

-- IMPORTANT: `for all` needs BOTH `using` AND `with check` to cover INSERT
-- (see stage1_itineraries.sql comment on itineraries_owner_all).
create policy "trip_segments_editor_write" on public.trip_segments
  for all
  using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where (m->>'user_id' = auth.uid()::text or m->>'userId' = auth.uid()::text)
              and m->>'role' in ('owner', 'editor')
          )
        )
    )
  )
  with check (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where (m->>'user_id' = auth.uid()::text or m->>'userId' = auth.uid()::text)
              and m->>'role' in ('owner', 'editor')
          )
        )
    )
  );

alter publication supabase_realtime add table public.trip_segments;

-- -----------------------------------------------------------------------------
-- 3. Premium feature flags
--    A general-purpose, DB-backed gating mechanism reusable for future premium
--    features beyond Google Maps. `feature_flags` is a small, admin-controlled
--    table (no insert/update/delete policy — only the service role, e.g. via
--    the Supabase dashboard or a future admin RPC, can change flags).
--
--    Gating rule (evaluated client-side): a feature is gated if
--    `requires_premium = true` AND (`free_until` is null OR now() > free_until).
--    A gated feature is usable only by users who are currently premium — see
--    profile_status below.
--
--    For now: google_maps ships with requires_premium = false, i.e. free for
--    everyone. Flipping it to true later gates it for non-premium users;
--    setting free_until grants a temporary grace-period override without
--    touching requires_premium.
-- -----------------------------------------------------------------------------

-- Drop earlier single-column premium flags from this same stage if already
-- applied in a prior run — profile_status (below) supersedes both.
alter table public.profiles drop column if exists is_premium;
alter table public.profiles drop column if exists premium_until;
alter table public.profiles drop column if exists premium_source;

-- profile_status is an append-only history log, not a single mutable column
-- — mirrors the existing username_history / profile_change_log pattern
-- (stage16) rather than overwriting state in place. Each row is one event:
--   (2026-01-01, premium, "14-day trial on signup", expires_at=2026-01-15)
--   (2026-01-15, normal,  "14-day trial ended")
--   (2026-03-01, premium, "bought subscription", expires_at=null)
-- "Is the user premium right now" is always: the single most recent row for
-- that user, checked against expires_at. Nobody ever has to guess why a date
-- is sitting on the profiles table six months from now.
create table if not exists public.profile_status (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users(id) on delete cascade,
  status      text        not null check (status in ('premium', 'normal')),
  reason      text        not null,
  expires_at  timestamptz, -- only meaningful when status = 'premium'; null = indefinite
  created_at  timestamptz not null default now()
);

create index if not exists profile_status_user_id_idx
  on public.profile_status (user_id, created_at desc);

alter table public.profile_status enable row level security;

drop policy if exists "profile_status_owner_read" on public.profile_status;

create policy "profile_status_owner_read" on public.profile_status
  for select using (user_id = auth.uid());

-- No insert/update/delete policy for authenticated/anon — rows are only
-- written by handle_new_user (below) and close_expired_premium_status, both
-- SECURITY DEFINER, or directly by the service role for goodwill/subscription
-- grants (e.g. `insert into profile_status (user_id, status, reason)
-- values ('<uid>', 'premium', 'goodwill: refund good faith credit')`).

-- Lazily closes an expired premium grant by inserting the terminating
-- "normal" row — called by the client right before it reads its own status,
-- so the log stays accurate with no cron/scheduled job needed. Idempotent:
-- once the terminating row exists, the latest row is already 'normal' and
-- this is a no-op on every subsequent call.
create or replace function public.close_expired_premium_status()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  _uid uuid := auth.uid();
  _latest record;
begin
  if _uid is null then
    return;
  end if;

  select * into _latest
  from public.profile_status
  where user_id = _uid
  order by created_at desc
  limit 1;

  if found
     and _latest.status = 'premium'
     and _latest.expires_at is not null
     and _latest.expires_at <= now() then
    insert into public.profile_status (user_id, status, reason)
    values (_uid, 'normal', _latest.reason || ' — ended');
  end if;
end;
$$;

create table if not exists public.feature_flags (
  feature_key      text        primary key,
  requires_premium boolean     not null default false,
  free_until       timestamptz,
  description      text,
  updated_at       timestamptz not null default now()
);

alter table public.feature_flags enable row level security;

drop policy if exists "feature_flags_read_all" on public.feature_flags;

create policy "feature_flags_read_all" on public.feature_flags
  for select using (true);

-- No write policy: feature_flags is only mutated via the service role.

insert into public.feature_flags (feature_key, requires_premium, description)
values ('google_maps', false, 'Google Maps as the route map renderer (vs. the free OpenStreetMap default)')
on conflict (feature_key) do nothing;

alter publication supabase_realtime add table public.feature_flags;

-- -----------------------------------------------------------------------------
-- 4. App config — generic key/value table for small tunables.
--    First use: trial_duration_days, so the signup free-trial length (14 or
--    30 days) is an ops change (UPDATE one row), not a code deploy. Same
--    read-all/service-role-write pattern as feature_flags.
-- -----------------------------------------------------------------------------

create table if not exists public.app_config (
  key        text        primary key,
  value      text        not null,
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

drop policy if exists "app_config_read_all" on public.app_config;

create policy "app_config_read_all" on public.app_config
  for select using (true);

-- No write policy: app_config is only mutated via the service role.

insert into public.app_config (key, value)
values ('trial_duration_days', '14')
on conflict (key) do nothing;

-- -----------------------------------------------------------------------------
-- 5. Grant a signup free trial via handle_new_user
--    Reissues the stage16 handle_new_user function (identical signature —
--    create or replace is enough, no drop needed) to also log a 'premium'
--    profile_status row (reason: signup trial, expires_at: now + trial_days)
--    for every new profile row.
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _trial_days int;
begin
  select coalesce(value::int, 14) into _trial_days
  from public.app_config where key = 'trial_duration_days';
  _trial_days := coalesce(_trial_days, 14);

  insert into public.profiles (id, display_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', ''),
    new.email
  )
  on conflict (id) do nothing;

  insert into public.profile_status (user_id, status, reason, expires_at)
  values (
    new.id,
    'premium',
    _trial_days || '-day trial on signup',
    now() + make_interval(days => _trial_days)
  );

  perform public.seed_notification_preferences(new.id);

  return new;
end;
$$;

-- Backfill the trial for existing users with no profile_status row yet
-- (idempotent — only inserts for users who don't already have one logged).
insert into public.profile_status (user_id, status, reason, expires_at)
select
  p.id,
  'premium',
  (select coalesce(value::int, 14) from public.app_config
    where key = 'trial_duration_days') || '-day trial (backfilled)',
  now() + make_interval(
    days => (select coalesce(value::int, 14) from public.app_config
      where key = 'trial_duration_days')
  )
from public.profiles p
where not exists (
  select 1 from public.profile_status ps where ps.user_id = p.id
);
