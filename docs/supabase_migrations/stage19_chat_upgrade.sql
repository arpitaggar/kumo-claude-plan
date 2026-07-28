-- Stage 19: Chat upgrade — attachments, read-receipt detail, push-notification plumbing
--
-- 1. Relaxes messages.content so attachment-only messages (no caption) are allowed.
-- 2. Adds message_attachments (images/files) + the 'chat-attachments' storage bucket.
-- 3. Adds message_reads (per-user read timestamp) alongside the existing read_by
--    array, powering a "who has seen this" detail view.
-- 4. Adds a 'chat_messages' notification category and a push-preview toggle on
--    profiles, both consumed by a future push-sending Edge Function.
-- 5. Adds push_tokens for registering device FCM tokens.
--
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS throughout.
-- Run in Supabase SQL editor before deploying the corresponding app update.

-- ── 1. Relax messages.content check ──────────────────────────────────────────

alter table public.messages
  drop constraint if exists messages_content_check;

alter table public.messages
  add constraint messages_content_check check (char_length(content) between 0 and 4000);

-- ── 2. message_attachments ───────────────────────────────────────────────────

create table if not exists public.message_attachments (
  id           uuid        primary key default gen_random_uuid(),
  message_id   uuid        not null references public.messages(id) on delete cascade,
  storage_path text        not null,
  public_url   text        not null,
  file_name    text        not null,
  mime_type    text        not null,
  size_bytes   bigint      not null,
  kind         text        not null check (kind in ('image', 'file')),
  created_at   timestamptz not null default now()
);

alter table public.message_attachments enable row level security;

drop policy if exists "message_attachments_member_read" on public.message_attachments;
drop policy if exists "message_attachments_sender_insert" on public.message_attachments;

-- Readable by anyone who can read the parent message (itinerary owner or member).
create policy "message_attachments_member_read" on public.message_attachments
  for select using (
    exists (
      select 1 from public.messages m
      join public.itineraries i on i.id = m.itinerary_id
      where m.id = message_id
        and (
          i.owner_id = auth.uid()
          or i.members @> jsonb_build_array(
               jsonb_build_object('userId', auth.uid()::text)
             )
        )
    )
  );

-- Only the message's own sender can attach a file to it.
create policy "message_attachments_sender_insert" on public.message_attachments
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.messages m
      where m.id = message_id
        and m.sender_id = auth.uid()
    )
  );

-- ── 3. chat-attachments storage bucket ───────────────────────────────────────
-- Same owner-folder pattern as the 'avatars' bucket (stage18): public read,
-- writes restricted to the caller's own {uid}/ prefix.

insert into storage.buckets (id, name, public)
values ('chat-attachments', 'chat-attachments', true)
on conflict (id) do nothing;

drop policy if exists "chat_attachments_public_read" on storage.objects;
create policy "chat_attachments_public_read" on storage.objects
  for select
  using (bucket_id = 'chat-attachments');

drop policy if exists "chat_attachments_owner_insert" on storage.objects;
create policy "chat_attachments_owner_insert" on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "chat_attachments_owner_delete" on storage.objects;
create policy "chat_attachments_owner_delete" on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ── 4. message_reads (per-user read timestamp) ───────────────────────────────

create table if not exists public.message_reads (
  message_id uuid        not null references public.messages(id) on delete cascade,
  user_id    uuid        not null references auth.users(id) on delete cascade,
  read_at    timestamptz not null default now(),
  primary key (message_id, user_id)
);

alter table public.message_reads enable row level security;

-- No direct client access — reads happen only through mark_messages_read() and
-- get_message_read_receipts() below, both SECURITY DEFINER.
drop policy if exists "message_reads_none" on public.message_reads;

-- Reissue mark_messages_read() to also upsert into message_reads.
create or replace function public.mark_messages_read(p_itinerary_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.messages
  set read_by = array_append(read_by, auth.uid()::text)
  where itinerary_id = p_itinerary_id
    and sender_id    != auth.uid()
    and not (read_by @> array[auth.uid()::text]);

  insert into public.message_reads (message_id, user_id)
  select m.id, auth.uid()
  from public.messages m
  where m.itinerary_id = p_itinerary_id
    and m.sender_id    != auth.uid()
  on conflict (message_id, user_id) do nothing;
end;
$$;

revoke all on function public.mark_messages_read(uuid) from anon;
grant execute on function public.mark_messages_read(uuid) to authenticated;

-- RPC: read-receipt detail for one message — sender-only (long-press "message info").
create or replace function public.get_message_read_receipts(p_message_id uuid)
returns table (
  user_id      uuid,
  display_name text,
  avatar_url   text,
  read_at      timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.messages
    where id = p_message_id and sender_id = auth.uid()
  ) then
    raise exception 'Only the sender can view read receipts for this message';
  end if;

  return query
    select p.id, p.display_name, p.avatar_url, mr.read_at
    from public.message_reads mr
    join public.profiles p on p.id = mr.user_id
    where mr.message_id = p_message_id
    order by mr.read_at asc;
end;
$$;

revoke all on function public.get_message_read_receipts(uuid) from anon;
grant execute on function public.get_message_read_receipts(uuid) to authenticated;

-- ── 5. Notification plumbing: chat_messages category + preview toggle ───────

alter table public.notification_preferences
  drop constraint if exists notification_preferences_category_check;

alter table public.notification_preferences
  add constraint notification_preferences_category_check check (category in (
    'trip_invites', 'expense_activity', 'flight_alerts',
    'collab_updates', 'marketing_engagement', 'chat_messages'
  ));

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
      'collab_updates', 'marketing_engagement', 'chat_messages'
    ] loop
      _enabled := (_category <> 'marketing_engagement');
      insert into public.notification_preferences (user_id, channel, category, enabled)
      values (p_user_id, _channel, _category, _enabled)
      on conflict (user_id, channel, category) do nothing;
    end loop;
  end loop;
end;
$$;

-- Backfill the new category for existing users.
do $$
declare r record;
begin
  for r in select id from auth.users loop
    perform public.seed_notification_preferences(r.id);
  end loop;
end;
$$;

alter table public.profiles
  add column if not exists push_message_preview_enabled boolean not null default true;

-- `create or replace` only replaces a function with an identical parameter
-- list. The stage18 version of update_profile had 13 params; adding
-- p_push_message_preview here makes 14, so without an explicit drop first,
-- Postgres would keep both as overloads and make the bare-name grant/revoke
-- below (and any bare-name reference to public.update_profile) ambiguous.
drop function if exists public.update_profile(
  text, text, text, text, text, text, text, text, text, text[], text, text, text
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
  p_push_message_preview boolean default null
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
  text, text, text, text, text, text, text, text, text, text[], text, text, text, boolean
) from anon;
grant execute on function public.update_profile(
  text, text, text, text, text, text, text, text, text, text[], text, text, text, boolean
) to authenticated;

-- ── 6. push_tokens ────────────────────────────────────────────────────────────

create table if not exists public.push_tokens (
  user_id    uuid        not null references auth.users(id) on delete cascade,
  token      text        not null,
  platform   text        not null check (platform in ('ios', 'android')),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

alter table public.push_tokens enable row level security;

drop policy if exists "push_tokens_owner_all" on public.push_tokens;
create policy "push_tokens_owner_all" on public.push_tokens
  for all
  using     (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.upsert_push_token(p_token text, p_platform text)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.push_tokens (user_id, token, platform, updated_at)
  values (auth.uid(), p_token, p_platform, now())
  on conflict (user_id, token)
  do update set platform = excluded.platform, updated_at = now();
$$;

revoke all on function public.upsert_push_token(text, text) from anon;
grant execute on function public.upsert_push_token(text, text) to authenticated;
