-- =============================================================================
-- Stage 47 — Modular accommodation sources: profile default + per-trip
-- override for which platforms (Airbnb/Expedia/Booking.com/Hostelworld/…)
-- show up on a trip's "Stay" tab (`lib/core/accommodation/`).
--
-- v1 of this feature is fully client-side/mocked — no real Airbnb/Expedia/
-- Booking.com/Hostelworld data flows through Postgres at all yet (see
-- `lib/core/accommodation/CLAUDE.md` for why: none of those platforms hand
-- out self-serve API access). This migration only adds the two settings
-- columns that control which source *keys* a user/trip has enabled —
-- nothing here depends on any external API existing yet, and nothing here
-- needs to change when a real source is eventually wired in.
--
-- Two settings layers, deliberately different null-semantics:
--   - profiles.enabled_accommodation_sources: nullable. NULL means "all
--     sources" (not "no sources") — so a source added to the app's catalog
--     later automatically appears for anyone who's never customized this.
--   - itineraries.accommodation_sources: NOT NULL, defaults to an empty
--     array as a safety net only. In practice the app always stamps a
--     concrete list here at trip-creation time (resolving the creator's
--     profile default, including resolving NULL to "every source key known
--     at that moment"), so a trip's setting never silently changes later
--     just because the profile default changes or a new source ships.
--
-- No new tables — both are ALTER TABLE ADD COLUMN on existing tables, so
-- this migration has no interaction with the SEC-033 age-gate trigger
-- coverage (require_age_verified(), stage46) or its pre-commit lint
-- (scripts/check_age_gate_coverage.sh), which only scans CREATE TABLE
-- statements.
--
-- Safe to re-run: uses ADD COLUMN IF NOT EXISTS / CREATE OR REPLACE
-- throughout. Run in Supabase SQL editor before deploying the
-- corresponding app build.
-- =============================================================================

-- ── 1. Settings columns ──────────────────────────────────────────────────────

alter table public.profiles
  add column if not exists enabled_accommodation_sources text[];

comment on column public.profiles.enabled_accommodation_sources is
  'Which accommodation source keys (see lib/core/accommodation/'
  'accommodation_source_meta.dart) this user wants shown by default. NULL '
  'means "all currently-known sources", not "none" — never treat NULL as '
  'an empty allow-list.';

alter table public.itineraries
  add column if not exists accommodation_sources text[] not null default array[]::text[];

comment on column public.itineraries.accommodation_sources is
  'Which accommodation source keys this specific trip has enabled — always '
  'a concrete list once a trip exists (stamped at creation from the '
  'creator''s profile default, resolving NULL there to every source key '
  'known at that moment), independently editable afterward from the trip '
  'detail page. The empty-array default here is only a safety net for a '
  'row inserted outside the normal create-trip flow; the app never leaves '
  'this empty for a real trip.';

-- ── 2. update_profile RPC reissue (14 -> 15 params) ──────────────────────────
-- `create or replace` only replaces a function with an identical parameter
-- list — the stage19 version had 14 params; adding
-- p_enabled_accommodation_sources here makes 15, so an explicit drop first
-- is required or Postgres keeps both as ambiguous overloads (same reasoning
-- stage19's own header comment gives for its 13->14 change).

drop function if exists public.update_profile(
  text, text, text, text, text, text, text, text, text, text[], text, text, text, boolean
);

create or replace function public.update_profile(
  p_display_name        text    default null,
  p_username            text    default null,
  p_bio                 text    default null,
  p_city                text    default null,
  p_country             text    default null,
  p_timezone            text    default null,
  p_preferred_currency  text    default null,
  p_preferred_language  text    default null,
  p_units_preference    text    default null,
  p_travel_tags         text[]  default null,
  p_profile_visibility  text    default null,
  p_contact_visibility  text    default null,
  p_avatar_url          text    default null,
  p_push_message_preview boolean default null,
  p_enabled_accommodation_sources text[] default null
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

  -- Ensure the profile row exists (handles accounts created before the trigger).
  insert into public.profiles (id, display_name, email)
  select _uid,
         coalesce(p_display_name, (select raw_user_meta_data->>'display_name' from auth.users where id = _uid), ''),
         (select email from auth.users where id = _uid)
  on conflict (id) do nothing;

  -- Username change: validate, enforce cooldown, log history.
  if p_username is not null then
    select username into _old_username from public.profiles where id = _uid;

    if lower(p_username) is distinct from lower(_old_username) then

      if p_username !~ '^[a-zA-Z0-9][a-zA-Z0-9_]{1,28}[a-zA-Z0-9]$' then
        raise exception 'Username must be 3–30 characters: letters, numbers, underscores only, no leading/trailing underscore.';
      end if;

      if exists (
        select 1 from public.profiles
        where lower(username) = lower(p_username)
          and id != _uid
      ) then
        raise exception 'Username already taken';
      end if;

      if exists (
        select 1 from public.profiles
        where id = _uid
          and username_last_changed_at > now() - interval '7 days'
      ) then
        raise exception 'Username can only be changed once every 7 days';
      end if;

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
    push_message_preview_enabled = coalesce(p_push_message_preview, push_message_preview_enabled),
    enabled_accommodation_sources = coalesce(p_enabled_accommodation_sources, enabled_accommodation_sources),
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

revoke all on function public.update_profile(
  text, text, text, text, text, text, text, text, text, text[], text, text, text, boolean, text[]
) from anon;
grant execute on function public.update_profile(
  text, text, text, text, text, text, text, text, text, text[], text, text, text, boolean, text[]
) to authenticated;
