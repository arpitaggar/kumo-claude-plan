-- Stage 16: Extended user profiles
--
-- Adds username, bio, localisation fields, travel preference tags, visibility
-- controls, notification preferences, username history, and profile change log.
--
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE throughout.
-- Run in Supabase SQL editor before deploying the corresponding app update.
--
-- NOTE: user_id is the *only* FK target across the schema. Never use username
-- as a foreign key — it is mutable. The UUID id column is stable forever.

-- ── 1. Extend profiles table ─────────────────────────────────────────────────

alter table public.profiles
  add column if not exists username                text,
  add column if not exists bio                     text,
  add column if not exists city                    text,
  add column if not exists country                 char(2),     -- ISO 3166-1 alpha-2
  add column if not exists timezone                text,
  add column if not exists preferred_currency      char(3),     -- ISO 4217
  add column if not exists preferred_language      char(2),     -- ISO 639-1
  add column if not exists units_preference        text not null default 'metric'
                              check (units_preference in ('metric', 'imperial')),
  add column if not exists travel_preference_tags  text[]       not null default '{}',
  add column if not exists profile_visibility      text not null default 'public'
                              check (profile_visibility in ('public', 'private')),
  add column if not exists contact_visibility      text not null default 'collaborators_only'
                              check (contact_visibility in ('collaborators_only', 'hidden')),
  add column if not exists username_last_changed_at timestamptz,
  add column if not exists updated_at              timestamptz not null default now();

-- Case-insensitive unique index for username; NULLs are distinct (existing
-- users without a username don't collide).
create unique index if not exists profiles_username_unique
  on public.profiles (lower(username))
  where username is not null;

-- ── 2. username_history ──────────────────────────────────────────────────────
-- Records every previous username so app links can 301-redirect to the current
-- one rather than 404. Only the owner can read their own history.

create table if not exists public.username_history (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null references auth.users(id) on delete cascade,
  old_username text        not null,
  changed_at   timestamptz not null default now()
);

alter table public.username_history enable row level security;

drop policy if exists "username_history_owner_select" on public.username_history;
create policy "username_history_owner_select" on public.username_history
  for select using (auth.uid() = user_id);

-- ── 3. profile_change_log ────────────────────────────────────────────────────
-- Audit trail for field changes. Sensitive values (email/phone) are not stored
-- here — those live in auth.users and are managed by Supabase Auth. This table
-- records application-layer profile field changes such as username.

create table if not exists public.profile_change_log (
  id            uuid        primary key default gen_random_uuid(),
  user_id       uuid        not null references auth.users(id) on delete cascade,
  field_changed text        not null,
  old_value     text,
  new_value     text,
  changed_at    timestamptz not null default now()
);

alter table public.profile_change_log enable row level security;

drop policy if exists "profile_change_log_owner_select" on public.profile_change_log;
create policy "profile_change_log_owner_select" on public.profile_change_log
  for select using (auth.uid() = user_id);

-- ── 4. notification_preferences ─────────────────────────────────────────────
-- One row per (user, channel, category) combination. The owner can read and
-- write their own rows; no one else has access.

create table if not exists public.notification_preferences (
  user_id  uuid not null references auth.users(id) on delete cascade,
  channel  text not null check (channel  in ('push', 'email', 'sms')),
  category text not null check (category in (
              'trip_invites', 'expense_activity', 'flight_alerts',
              'collab_updates', 'marketing_engagement'
            )),
  enabled  bool not null default true,
  primary key (user_id, channel, category)
);

alter table public.notification_preferences enable row level security;

drop policy if exists "notif_prefs_owner_all" on public.notification_preferences;
create policy "notif_prefs_owner_all" on public.notification_preferences
  for all
  using     (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ── 5. Helper: seed notification defaults for one user ───────────────────────
-- All categories default ON except marketing_engagement (GDPR opt-in).

create or replace function public.seed_notification_preferences(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  _channel  text;
  _category text;
  _enabled  bool;
begin
  foreach _channel in array array['push', 'email', 'sms'] loop
    foreach _category in array array[
      'trip_invites', 'expense_activity', 'flight_alerts',
      'collab_updates', 'marketing_engagement'
    ] loop
      _enabled := (_category <> 'marketing_engagement');
      insert into public.notification_preferences (user_id, channel, category, enabled)
      values (p_user_id, _channel, _category, _enabled)
      on conflict (user_id, channel, category) do nothing;
    end loop;
  end loop;
end;
$$;

-- ── 6. Update handle_new_user to seed notification preferences on signup ─────

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', ''),
    new.email
  )
  on conflict (id) do nothing;

  perform public.seed_notification_preferences(new.id);

  return new;
end;
$$;

-- Backfill notification preferences for users who signed up before this migration.
do $$
declare r record;
begin
  for r in select id from auth.users loop
    perform public.seed_notification_preferences(r.id);
  end loop;
end;
$$;

-- ── 7. RPC: update own profile ───────────────────────────────────────────────
-- Handles all profile field updates. Username changes are validated for:
--   • Format (3–30 chars, alphanumeric + underscores, no leading/trailing _)
--   • Uniqueness (case-insensitive)
--   • 7-day cooldown between changes
-- History + change log rows are inserted atomically on username change.
-- All other fields use COALESCE so passing NULL leaves the column unchanged.

create or replace function public.update_profile(
  p_display_name      text    default null,
  p_username          text    default null,
  p_bio               text    default null,
  p_city              text    default null,
  p_country           text    default null,
  p_timezone          text    default null,
  p_preferred_currency text   default null,
  p_preferred_language text   default null,
  p_units_preference  text    default null,
  p_travel_tags       text[]  default null,
  p_profile_visibility  text  default null,
  p_contact_visibility  text  default null,
  p_avatar_url        text    default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  _uid          uuid := auth.uid();
  _old_username text;
begin
  if _uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Username change: validate, enforce cooldown, log history
  if p_username is not null then
    select username into _old_username from public.profiles where id = _uid;

    -- Skip all validation if username hasn't changed
    if lower(p_username) is distinct from lower(_old_username) then

      -- Format check
      if p_username !~ '^[a-zA-Z0-9][a-zA-Z0-9_]{1,28}[a-zA-Z0-9]$' then
        raise exception 'Username must be 3–30 characters: letters, numbers, underscores only, no leading/trailing underscore.';
      end if;

      -- Uniqueness check (case-insensitive, excluding self)
      if exists (
        select 1 from public.profiles
        where lower(username) = lower(p_username)
          and id != _uid
      ) then
        raise exception 'Username already taken';
      end if;

      -- 7-day cooldown
      if exists (
        select 1 from public.profiles
        where id = _uid
          and username_last_changed_at > now() - interval '7 days'
      ) then
        raise exception 'Username can only be changed once every 7 days';
      end if;

      -- Log history and change log if old username existed
      if _old_username is not null then
        insert into public.username_history (user_id, old_username)
        values (_uid, _old_username);

        insert into public.profile_change_log (user_id, field_changed, old_value, new_value)
        values (_uid, 'username', _old_username, p_username);
      end if;

    end if;
  end if;

  update public.profiles
  set
    display_name              = coalesce(p_display_name,        display_name),
    username                  = coalesce(p_username,            username),
    bio                       = coalesce(p_bio,                 bio),
    city                      = coalesce(p_city,                city),
    country                   = coalesce(p_country,             country),
    timezone                  = coalesce(p_timezone,            timezone),
    preferred_currency        = coalesce(p_preferred_currency,  preferred_currency),
    preferred_language        = coalesce(p_preferred_language,  preferred_language),
    units_preference          = coalesce(p_units_preference,    units_preference),
    travel_preference_tags    = coalesce(p_travel_tags,         travel_preference_tags),
    profile_visibility        = coalesce(p_profile_visibility,  profile_visibility),
    contact_visibility        = coalesce(p_contact_visibility,  contact_visibility),
    avatar_url                = coalesce(p_avatar_url,          avatar_url),
    username_last_changed_at  = case
      when p_username is not null
       and lower(p_username) is distinct from lower(
             (select username from public.profiles where id = _uid)
           )
      then now()
      else username_last_changed_at
    end,
    updated_at = now()
  where id = _uid;
end;
$$;

revoke all on function public.update_profile from anon;
grant execute on function public.update_profile to authenticated;

-- ── 8. RPC: upsert a single notification preference ─────────────────────────

create or replace function public.upsert_notification_preference(
  p_channel  text,
  p_category text,
  p_enabled  bool
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notification_preferences (user_id, channel, category, enabled)
  values (auth.uid(), p_channel, p_category, p_enabled)
  on conflict (user_id, channel, category)
  do update set enabled = excluded.enabled;
$$;

revoke all on function public.upsert_notification_preference(text, text, bool) from anon;
grant execute on function public.upsert_notification_preference(text, text, bool) to authenticated;
