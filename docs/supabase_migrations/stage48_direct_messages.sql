-- =============================================================================
-- Stage 48 — Private messaging (DMs) between two users, independent of any
-- shared trip.
--
-- Reuses the existing public.messages table rather than forking a parallel
-- one: itinerary_id becomes nullable and a new dm_conversation_id column is
-- added, with an XOR check constraint so a message is always attributable
-- to exactly one context — this is the same pattern stage45_hitchhikers.sql
-- already used for sender_id/hitchhiker_id. message_attachments, push_tokens,
-- the chat-attachments storage bucket, and mark_messages_read's sibling
-- get_message_read_receipts() are reused as-is or with a small added branch
-- — none of them reference itinerary_id in a way that needs to change. Group
-- chat (ChatRepository, messages_owner_all/_member_read/_member_insert) is
-- untouched: those policies all join through itinerary_id inside an
-- `exists (select ... where i.id = itinerary_id ...)`, which a DM row (null
-- itinerary_id) structurally never matches.
--
-- public.dm_conversations is the new "who is this thread between" table —
-- canonically ordered (user_a = least(x,y), user_b = greatest(x,y)) so the
-- unique index on (user_a, user_b) prevents a duplicate conversation no
-- matter which of the two users starts it. It has no client insert/update
-- policy at all: every write goes through get_or_create_dm_conversation()
-- below (SECURITY DEFINER, same RPC-only trust model stage45 uses for
-- trip_hitchhikers) or the touch_dm_conversation() trigger. last_message_at/
-- _preview/_sender_id are denormalized by that trigger specifically so the
-- DM inbox can stream this one table directly (ordered by last_message_at)
-- instead of watching every conversation's message stream individually —
-- deliberately a different mechanism than how the existing trip-chat inbox
-- derives "latest message" (left alone, per the decision not to touch chat).
--
-- public.blocked_users is a minimal safety net shipped in this same pass,
-- not as a follow-up: DMs make "a stranger found via search messages you
-- unsolicited" possible for the first time in this app, and there was no
-- block/report mechanism anywhere before this migration. A block in either
-- direction stops get_or_create_dm_conversation() from creating a new
-- thread and stops messages_dm_participant_insert from accepting a new
-- message in an existing one — enforced at the RLS/RPC layer, not just a
-- client-side UI disable.
--
-- Both new tables get the require_age_verified() trigger (stage46) rather
-- than an age-gate-exempt comment, matching every other user-content table.
-- auth.uid() inside a SECURITY DEFINER function still reflects the original
-- caller's JWT, not the function owner, so the trigger correctly gates an
-- unverified caller's get_or_create_dm_conversation()/block_user() call —
-- same reasoning stage46's header comment gives for the Hitchhiker RPCs'
-- writes into messages.
--
-- Safe to re-run: uses CREATE OR REPLACE / DROP POLICY IF EXISTS / DROP
-- TRIGGER IF EXISTS / ADD COLUMN IF NOT EXISTS throughout. Run in Supabase
-- SQL editor before deploying the corresponding app build.
-- =============================================================================

-- ── 1. dm_conversations ──────────────────────────────────────────────────────

create table if not exists public.dm_conversations (
  id                      uuid        primary key default gen_random_uuid(),
  user_a                  uuid        not null references auth.users(id) on delete cascade,
  user_b                  uuid        not null references auth.users(id) on delete cascade,
  created_at              timestamptz not null default now(),
  last_message_at         timestamptz,
  last_message_preview    text,
  last_message_sender_id  uuid,
  check (user_a <> user_b)
);

create unique index if not exists dm_conversations_pair_idx
  on public.dm_conversations (user_a, user_b);

comment on table public.dm_conversations is
  'One row per pair of users who have exchanged a direct message. '
  'Canonically ordered (user_a = least(x,y), user_b = greatest(x,y)) so the '
  'unique (user_a, user_b) index prevents a duplicate thread — see '
  'get_or_create_dm_conversation(). No client write policy; every row is '
  'created by that RPC and updated by touch_dm_conversation().';

alter table public.dm_conversations enable row level security;

drop policy if exists "dm_conversations_participant_read" on public.dm_conversations;

create policy "dm_conversations_participant_read" on public.dm_conversations
  for select using (
    auth.uid() = user_a or auth.uid() = user_b
  );

-- ── 2. blocked_users ─────────────────────────────────────────────────────────

create table if not exists public.blocked_users (
  blocker_id uuid        not null references auth.users(id) on delete cascade,
  blocked_id uuid        not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

comment on table public.blocked_users is
  'A block is one-directional and private to the blocker — blocked_id is '
  'never told they were blocked. Checked by get_or_create_dm_conversation() '
  'and messages_dm_participant_insert (both directions) so a block actually '
  'stops new messages, not just hides the option in the UI.';

alter table public.blocked_users enable row level security;

drop policy if exists "blocked_users_owner_all" on public.blocked_users;

create policy "blocked_users_owner_all" on public.blocked_users
  for all
  using     (auth.uid() = blocker_id)
  with check (auth.uid() = blocker_id);

-- ── 3. messages: allow DM-scoped rows ─────────────────────────────────────────

alter table public.messages
  alter column itinerary_id drop not null;

alter table public.messages
  add column if not exists dm_conversation_id uuid references public.dm_conversations(id) on delete cascade;

-- Exactly one of itinerary_id (group chat) / dm_conversation_id (DM) is set —
-- mirrors messages_sender_xor_hitchhiker's XOR shape from stage45, applied
-- to "what is this message posted in" instead of "who posted it". A DM
-- message's sender is always sender_id (never hitchhiker_id) — Hitchhikers
-- are trip-scoped non-account collaborators with no user_id, so they
-- structurally can't be a dm_conversations participant; no new constraint
-- is needed to enforce that, it falls out of dm_conversations.user_a/user_b
-- both being NOT NULL references to auth.users(id).
alter table public.messages
  drop constraint if exists messages_itinerary_xor_dm;
alter table public.messages
  add constraint messages_itinerary_xor_dm
  check ((itinerary_id is not null) <> (dm_conversation_id is not null));

comment on column public.messages.dm_conversation_id is
  'Set instead of itinerary_id when this is a direct message. Exactly one '
  'of the two is set — see messages_itinerary_xor_dm.';

-- messages_owner_all / messages_member_read / messages_member_insert
-- (stage2/stage13) all key off itinerary_id inside an
-- `exists (select ... from itineraries i where i.id = itinerary_id ...)` —
-- a DM row (itinerary_id null) structurally never matches any of them, so
-- no edit is needed there. Same reasoning applies unchanged to
-- message_attachments_member_read/_sender_insert (stage19/23) and the
-- chat_attachments_member_read storage policy (stage43), all of which join
-- through itinerary_id. New sibling policies below (permissive/OR'd with
-- the itinerary ones, per Postgres RLS semantics) cover the DM case.

drop policy if exists "messages_dm_participant_read" on public.messages;

create policy "messages_dm_participant_read" on public.messages
  for select using (
    dm_conversation_id is not null
    and exists (
      select 1 from public.dm_conversations c
      where c.id = dm_conversation_id
        and (c.user_a = auth.uid() or c.user_b = auth.uid())
    )
  );

drop policy if exists "messages_dm_participant_insert" on public.messages;

create policy "messages_dm_participant_insert" on public.messages
  for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and dm_conversation_id is not null
    and exists (
      select 1 from public.dm_conversations c
      where c.id = dm_conversation_id
        and (c.user_a = auth.uid() or c.user_b = auth.uid())
        and not exists (
          select 1 from public.blocked_users b
          where (b.blocker_id = auth.uid() and b.blocked_id = case when c.user_a = auth.uid() then c.user_b else c.user_a end)
             or (b.blocked_id = auth.uid() and b.blocker_id = case when c.user_a = auth.uid() then c.user_b else c.user_a end)
        )
    )
  );

-- No messages_dm_owner_all-style for-all/delete/update policy — this app
-- never edits or deletes a sent message in group chat either, so none is
-- needed here for parity.

-- ── 4. message_attachments: DM branch ────────────────────────────────────────

drop policy if exists "message_attachments_dm_participant_read" on public.message_attachments;

create policy "message_attachments_dm_participant_read" on public.message_attachments
  for select using (
    exists (
      select 1 from public.messages m
      join public.dm_conversations c on c.id = m.dm_conversation_id
      where m.id = message_id
        and (c.user_a = auth.uid() or c.user_b = auth.uid())
    )
  );

-- message_attachments_sender_insert (stage19) already only checks the
-- message's own sender, itinerary-agnostic — no DM-specific change needed.

-- ── 5. chat-attachments storage: DM branch ───────────────────────────────────

drop policy if exists "chat_attachments_dm_participant_read" on storage.objects;

create policy "chat_attachments_dm_participant_read" on storage.objects
  for select
  using (
    bucket_id = 'chat-attachments'
    and exists (
      select 1
      from public.message_attachments ma
      join public.messages m on m.id = ma.message_id
      join public.dm_conversations c on c.id = m.dm_conversation_id
      where ma.storage_path = storage.objects.name
        and (c.user_a = auth.uid() or c.user_b = auth.uid())
    )
  );

-- chat_attachments_owner_insert / _delete (stage19) are unaffected — DM
-- attachments upload through the exact same {uid}/ prefix convention.

-- ── 6. touch_dm_conversation trigger ─────────────────────────────────────────

create or replace function public.touch_dm_conversation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.dm_conversations
  set last_message_at        = new.created_at,
      last_message_preview   = left(new.content, 200),
      last_message_sender_id = new.sender_id
  where id = new.dm_conversation_id;
  return new;
end;
$$;

drop trigger if exists trg_touch_dm_conversation on public.messages;
create trigger trg_touch_dm_conversation
  after insert on public.messages
  for each row when (new.dm_conversation_id is not null)
  execute function public.touch_dm_conversation();

-- ── 7. get_or_create_dm_conversation ─────────────────────────────────────────

create or replace function public.get_or_create_dm_conversation(p_other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  _uid uuid := auth.uid();
  _a   uuid;
  _b   uuid;
  _id  uuid;
begin
  if _uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_other_user_id is null or p_other_user_id = _uid then
    raise exception 'Cannot start a conversation with yourself';
  end if;
  if not exists (select 1 from public.profiles where id = p_other_user_id) then
    raise exception 'User not found';
  end if;
  if exists (
    select 1 from public.blocked_users
    where (blocker_id = _uid and blocked_id = p_other_user_id)
       or (blocker_id = p_other_user_id and blocked_id = _uid)
  ) then
    raise exception 'You cannot message this user';
  end if;

  _a := least(_uid, p_other_user_id);
  _b := greatest(_uid, p_other_user_id);

  insert into public.dm_conversations (user_a, user_b)
  values (_a, _b)
  on conflict (user_a, user_b) do nothing
  returning id into _id;

  if _id is null then
    select id into _id from public.dm_conversations where user_a = _a and user_b = _b;
  end if;

  return _id;
end;
$$;

revoke all on function public.get_or_create_dm_conversation(uuid) from anon;
grant execute on function public.get_or_create_dm_conversation(uuid) to authenticated;

-- ── 8. mark_dm_messages_read ─────────────────────────────────────────────────
-- New sibling to mark_messages_read(p_itinerary_id) (stage19), not a widened
-- version of it — avoids risking that already-tested itinerary-scoped RPC.
-- get_message_read_receipts(p_message_id) (stage19) needs no change at all:
-- it's already keyed only by message_id, itinerary-agnostic, reused as-is.

create or replace function public.mark_dm_messages_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.dm_conversations c
    where c.id = p_conversation_id
      and (c.user_a = auth.uid() or c.user_b = auth.uid())
  ) then
    raise exception 'Conversation not found';
  end if;

  update public.messages
  set read_by = array_append(read_by, auth.uid()::text)
  where dm_conversation_id = p_conversation_id
    and sender_id           != auth.uid()
    and not (read_by @> array[auth.uid()::text]);

  insert into public.message_reads (message_id, user_id)
  select m.id, auth.uid()
  from public.messages m
  where m.dm_conversation_id = p_conversation_id
    and m.sender_id           != auth.uid()
  on conflict (message_id, user_id) do nothing;
end;
$$;

revoke all on function public.mark_dm_messages_read(uuid) from anon;
grant execute on function public.mark_dm_messages_read(uuid) to authenticated;

-- ── 9. block_user / unblock_user ─────────────────────────────────────────────

create or replace function public.block_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  _uid uuid := auth.uid();
begin
  if _uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_user_id is null or p_user_id = _uid then
    raise exception 'Invalid user';
  end if;

  insert into public.blocked_users (blocker_id, blocked_id)
  values (_uid, p_user_id)
  on conflict (blocker_id, blocked_id) do nothing;
end;
$$;

revoke all on function public.block_user(uuid) from anon;
grant execute on function public.block_user(uuid) to authenticated;

create or replace function public.unblock_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.blocked_users
  where blocker_id = auth.uid() and blocked_id = p_user_id;
end;
$$;

revoke all on function public.unblock_user(uuid) from anon;
grant execute on function public.unblock_user(uuid) to authenticated;

-- ── 10. Age-gate trigger coverage (SEC-033 future-proofing) ─────────────────

drop trigger if exists trg_require_age_verified on public.dm_conversations;
create trigger trg_require_age_verified
  before insert or update on public.dm_conversations
  for each row execute function public.require_age_verified();

drop trigger if exists trg_require_age_verified on public.blocked_users;
create trigger trg_require_age_verified
  before insert or update on public.blocked_users
  for each row execute function public.require_age_verified();

-- ── 11. Realtime ──────────────────────────────────────────────────────────────
-- public.messages is already in this publication (stage2) — the new
-- dm_conversation_id column rides along automatically. dm_conversations is
-- new and needs to be added explicitly so the DM inbox's conversation-list
-- stream updates live.

alter publication supabase_realtime add table public.dm_conversations;
