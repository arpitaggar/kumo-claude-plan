-- =============================================================================
-- Stage 38 — Post comments
--
-- Third and last of the three explicitly-deferred Stage 22 social-feed items
-- (unpublish/delete was stage36, activity notifications stage37 — see
-- docs/Checklist.md for both).
--
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. post_comments
--    Flat, non-threaded comments on a published post. author_name/avatar are
--    denormalised at insert time — same rationale as itinerary_posts' and
--    notifications' own author fields (stage22/37): the list renders with
--    zero joins, and a row still reads correctly if the commenter later
--    renames themselves. Deliberately NOT adding a stored comment_count
--    column on itinerary_posts — SCALE-001 (stage33) already hit exactly
--    this hot-row problem with like_count and the fix was to drop the
--    counter and count at read time via PostgREST's embedded-resource count
--    instead; comments get the read-time-count treatment from the start.
-- -----------------------------------------------------------------------------

create table if not exists public.post_comments (
  id                uuid        primary key default gen_random_uuid(),
  post_id           uuid        not null references public.itinerary_posts(id) on delete cascade,
  author_id         uuid        not null references auth.users(id) on delete cascade,
  author_name       text        not null,
  author_avatar_url text,
  content           text        not null,
  created_at        timestamptz not null default now(),
  constraint post_comments_content_check check (char_length(content) between 1 and 1000)
);

create index if not exists post_comments_post_id_created_at_idx
  on public.post_comments (post_id, created_at);

-- Backs the like_count-style read-time count (`post_comments(count)`) —
-- same reasoning as post_likes_user_id_created_at_idx (stage33), a
-- post_id-first index for a post_id-filtered count query.
create index if not exists post_comments_post_id_idx
  on public.post_comments (post_id);

alter table public.post_comments enable row level security;

drop policy if exists "post_comments_read_all"   on public.post_comments;
drop policy if exists "post_comments_own_insert" on public.post_comments;
drop policy if exists "post_comments_own_delete" on public.post_comments;

create policy "post_comments_read_all" on public.post_comments
  for select using (auth.role() = 'authenticated');

create policy "post_comments_own_insert" on public.post_comments
  for insert with check (author_id = auth.uid());

-- Immutable once written (no update policy) — delete-only, matching the
-- itinerary_posts pattern from stage36 (unpublish is a delete, not an edit).
create policy "post_comments_own_delete" on public.post_comments
  for delete using (author_id = auth.uid());

alter publication supabase_realtime add table public.post_comments;

-- -----------------------------------------------------------------------------
-- [Rate limit] Same BEFORE INSERT trigger-based approach as post_likes/
-- follows/itinerary_posts (stage33) — a direct client insert through
-- PostgREST with no Edge Function in front of it, so a DB trigger is the
-- only enforcement point available. 30/min is deliberately generous
-- (anti-spam, not pacing) — between follows' 30/min and post_likes' 60/min.
-- -----------------------------------------------------------------------------

create or replace function public.check_post_comments_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    select count(*) from public.post_comments
    where author_id = new.author_id and created_at > now() - interval '1 minute'
  ) >= 30 then
    raise exception 'Rate limit exceeded: too many comments in a short time. Please slow down.';
  end if;
  return new;
end;
$$;

drop trigger if exists post_comments_rate_limit on public.post_comments;

create trigger post_comments_rate_limit
  before insert on public.post_comments
  for each row execute function public.check_post_comments_rate_limit();

-- -----------------------------------------------------------------------------
-- 2. Notification on comment — extends stage37's notifications table/type
--    check rather than introducing a parallel mechanism. Unlike
--    notify_on_post_like, no profiles lookup is needed: post_comments
--    already denormalises the commenter's name/avatar onto NEW.
-- -----------------------------------------------------------------------------

alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check check (type in ('like', 'follow', 'new_post', 'comment'));

create or replace function public.notify_on_post_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _author_id  uuid;
  _post_title text;
begin
  select author_id, title into _author_id, _post_title
    from public.itinerary_posts where id = new.post_id;

  if _author_id is null or _author_id = new.author_id then
    return new;
  end if;

  insert into public.notifications
    (recipient_id, actor_id, actor_name, actor_avatar_url, type, post_id, post_title)
  values
    (_author_id, new.author_id, new.author_name, new.author_avatar_url,
     'comment', new.post_id, _post_title);
  return new;
end;
$$;

drop trigger if exists post_comments_notify on public.post_comments;

create trigger post_comments_notify
  after insert on public.post_comments
  for each row execute function public.notify_on_post_comment();
