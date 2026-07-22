-- Stage 18: Avatar storage bucket + profile upsert fix
--
-- 1. Creates the 'avatars' storage bucket and sets up RLS policies so
--    authenticated users can manage their own avatar file.
--
-- 2. Backfills missing profile rows for users who signed up before the
--    handle_new_user trigger was in place (root cause of "Profile not found").
--
-- 3. Replaces update_profile() to INSERT the profile row if missing before
--    attempting the UPDATE (upsert guard), so future sign-ups with a missing
--    profile row are handled gracefully without returning an error.
--
-- Safe to re-run: uses ON CONFLICT DO NOTHING / CREATE OR REPLACE throughout.
-- Run in Supabase SQL editor before deploying the corresponding app update.

-- ── 1. Avatars storage bucket ─────────────────────────────────────────────────

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Public read (avatar URLs embedded in UI must be accessible without auth).
drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
  for select
  using (bucket_id = 'avatars');

-- Authenticated users can upload files inside their own UID-named folder.
drop policy if exists "avatars_owner_insert" on storage.objects;
create policy "avatars_owner_insert" on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Overwrite (upsert) their own file.
drop policy if exists "avatars_owner_update" on storage.objects;
create policy "avatars_owner_update" on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Delete their own file (e.g. Remove Photo).
drop policy if exists "avatars_owner_delete" on storage.objects;
create policy "avatars_owner_delete" on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ── 2. Backfill missing profile rows ─────────────────────────────────────────
-- Users who signed up before handle_new_user was deployed may have no row in
-- public.profiles.  Insert a minimal row so the app can read and write it.

insert into public.profiles (id, email, display_name)
select
  u.id,
  u.email,
  coalesce(u.raw_user_meta_data->>'display_name', '')
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

-- ── 3. Replace update_profile to guard against missing profile rows ───────────
-- The previous version did a bare UPDATE which silently affected 0 rows when
-- the profile didn't exist, then the subsequent SELECT in getOwnProfile()
-- returned 0 rows → "Profile not found" error in the app.
-- This version inserts a minimal row first (ON CONFLICT DO NOTHING) so the
-- UPDATE always finds a target.

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
  p_avatar_url          text    default null
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
    display_name             = coalesce(p_display_name,       display_name),
    username                 = coalesce(p_username,            username),
    bio                      = coalesce(p_bio,                 bio),
    city                     = coalesce(p_city,                city),
    country                  = coalesce(p_country,             country),
    timezone                 = coalesce(p_timezone,            timezone),
    preferred_currency       = coalesce(p_preferred_currency,  preferred_currency),
    preferred_language       = coalesce(p_preferred_language,  preferred_language),
    units_preference         = coalesce(p_units_preference,    units_preference),
    travel_preference_tags   = coalesce(p_travel_tags,         travel_preference_tags),
    profile_visibility       = coalesce(p_profile_visibility,  profile_visibility),
    contact_visibility       = coalesce(p_contact_visibility,  contact_visibility),
    avatar_url               = coalesce(p_avatar_url,          avatar_url),
    username_last_changed_at = case
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
