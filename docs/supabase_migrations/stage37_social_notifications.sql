-- =============================================================================
-- Stage 37 — Social notifications: in-app feed + push for likes, follows, and
-- new posts from people you follow.
--
-- Second of three explicitly-deferred Stage 22 social-feed items (see that
-- stage's Checklist.md entry — unpublish/delete was the first, stage36).
--
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. notifications
--    One row per event the recipient should see in their activity feed.
--    Actor name/avatar and (like/new_post) post title are denormalised at
--    insert time — same rationale as itinerary_posts' author fields
--    (stage22): the feed renders with zero joins, and a row still reads
--    correctly if the actor later renames themselves or the post is edited
--    (it can't be — posts are immutable — but this also survives the actor
--    changing their display name).
-- -----------------------------------------------------------------------------

create table if not exists public.notifications (
  id               uuid        primary key default gen_random_uuid(),
  recipient_id     uuid        not null references auth.users(id) on delete cascade,
  actor_id         uuid        not null references auth.users(id) on delete cascade,
  actor_name       text        not null,
  actor_avatar_url text,
  type             text        not null check (type in ('like', 'follow', 'new_post')),
  post_id          uuid        references public.itinerary_posts(id) on delete cascade,
  post_title       text,
  read_at          timestamptz,
  created_at       timestamptz not null default now()
);

create index if not exists notifications_recipient_created_idx
  on public.notifications (recipient_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "notifications_recipient_read"   on public.notifications;
drop policy if exists "notifications_recipient_update" on public.notifications;

-- No insert policy at all, deliberately: every row is written by the
-- SECURITY DEFINER trigger functions below, never by a direct client
-- insert (an RLS table with zero insert policies rejects every client
-- insert attempt outright) — this is what stops a user from spoofing
-- "so-and-so liked your post" for a like that never happened.
create policy "notifications_recipient_read" on public.notifications
  for select using (recipient_id = auth.uid());

-- Update is allowed (mark-as-read only, enforced client-side by only ever
-- writing read_at) so recipients don't need an RPC just to clear their badge.
create policy "notifications_recipient_update" on public.notifications
  for update using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());

alter publication supabase_realtime add table public.notifications;

-- -----------------------------------------------------------------------------
-- 2. Triggers — one per source event, all SECURITY DEFINER since the
--    recipient (who doesn't own the source row) is who needs the insert.
-- -----------------------------------------------------------------------------

-- Like: recipient is the post's author. post_likes only has user_id, so the
-- actor's name/avatar needs a profiles lookup (new_post below doesn't, since
-- itinerary_posts already denormalises the author's name/avatar onto NEW).
create or replace function public.notify_on_post_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _author_id  uuid;
  _post_title text;
  _actor_name text;
  _actor_avatar text;
begin
  select author_id, title into _author_id, _post_title
    from public.itinerary_posts where id = new.post_id;

  -- Post already gone (race with a delete), or liking your own post —
  -- neither should produce a notification.
  if _author_id is null or _author_id = new.user_id then
    return new;
  end if;

  select display_name, avatar_url into _actor_name, _actor_avatar
    from public.profiles where id = new.user_id;

  insert into public.notifications
    (recipient_id, actor_id, actor_name, actor_avatar_url, type, post_id, post_title)
  values
    (_author_id, new.user_id, coalesce(_actor_name, ''), _actor_avatar,
     'like', new.post_id, _post_title);
  return new;
end;
$$;

drop trigger if exists post_likes_notify on public.post_likes;

create trigger post_likes_notify
  after insert on public.post_likes
  for each row execute function public.notify_on_post_like();

-- Follow: recipient is the followee. follows.check (follower_id <>
-- followee_id) already rules out a self-follow notification.
create or replace function public.notify_on_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _actor_name text;
  _actor_avatar text;
begin
  select display_name, avatar_url into _actor_name, _actor_avatar
    from public.profiles where id = new.follower_id;

  insert into public.notifications
    (recipient_id, actor_id, actor_name, actor_avatar_url, type)
  values
    (new.followee_id, new.follower_id, coalesce(_actor_name, ''), _actor_avatar,
     'follow');
  return new;
end;
$$;

drop trigger if exists follows_notify on public.follows;

create trigger follows_notify
  after insert on public.follows
  for each row execute function public.notify_on_follow();

-- New post: fan out to every follower of the author. Capped at 1000 most-
-- recently-followed — the same bound fetchFeed already applies when reading
-- (stage33) — so a wildly-followed account publishing doesn't turn one
-- insert into an unbounded one. A publish-time fan-out past that bound is a
-- background-queue problem (SCALE-002, documented, not attempted here), not
-- something a trigger should try to solve.
create or replace function public.notify_on_new_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications
    (recipient_id, actor_id, actor_name, actor_avatar_url, type, post_id, post_title)
  select follower_id, new.author_id, new.author_name, new.author_avatar_url,
         'new_post', new.id, new.title
  from public.follows
  where followee_id = new.author_id
  order by created_at desc
  limit 1000;
  return new;
end;
$$;

drop trigger if exists itinerary_posts_notify on public.itinerary_posts;

create trigger itinerary_posts_notify
  after insert on public.itinerary_posts
  for each row execute function public.notify_on_new_post();

-- -----------------------------------------------------------------------------
-- 3. social_activity notification category (same pattern stage19 used to
--    add chat_messages: widen the check constraint, reissue the seed
--    function with the new category, backfill existing users).
-- -----------------------------------------------------------------------------

alter table public.notification_preferences
  drop constraint if exists notification_preferences_category_check;

alter table public.notification_preferences
  add constraint notification_preferences_category_check check (category in (
    'trip_invites', 'expense_activity', 'flight_alerts',
    'collab_updates', 'marketing_engagement', 'chat_messages', 'social_activity'
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
      'collab_updates', 'marketing_engagement', 'chat_messages', 'social_activity'
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
