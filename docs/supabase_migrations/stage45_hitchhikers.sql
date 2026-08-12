-- =============================================================================
-- Stage 45 — Hitchhiker role: non-account trip collaborators.
--
-- Trip role model (see docs/ARCHITECTURE.md "Captain / Crew / Hitchhiker"):
--   Captain     — itineraries.owner_id. The trip owner. Full account (18+).
--   Crew       — an entry in itineraries.members (GroupMember/GroupMemberRole,
--                stage1/12/13). Full account (18+), own user_id, own login,
--                cross-trip identity. Unchanged by this migration — Crew
--                already *is* the existing member model, just named now.
--   Hitchhiker — new in this migration. NOT a full account. No user_id, no
--                login, no DOB, no email/phone, no cross-trip identity, no
--                discoverability. Scoped to exactly one trip, added by that
--                trip's Captain with nothing but a first name.
--
-- *** IMPORTANT — READ BEFORE "SIMPLIFYING" THIS ***
-- Hitchhiker is not a themed label for a lightweight guest account. It is
-- the mechanism that keeps Kumo outside COPPA (US, under-13), the UK/EU Age
-- Appropriate Design Code (applies to ANY under-18 user with their own
-- account/data profile — not just under-13), and GDPR's variable 13–16
-- digital-consent thresholds. The whole point is that a Hitchhiker never
-- becomes an independent data subject: no auth.users row, no profiles row,
-- nothing durable outside this trip. If a future change gives Hitchhikers a
-- user_id, an email field, or any way to be looked up outside the one trip
-- they were added to, it silently reintroduces exactly the minor-data-
-- controller obligations this design avoids. Don't merge Hitchhiker into
-- Crew as a "just add a nullable password" convenience — see
-- stage44_age_gate.sql and docs/ARCHITECTURE.md for the full rationale.
--
-- Authorization model: RLS is built entirely around auth.uid(), which a
-- Hitchhiker (no Supabase Auth session at all) never has. So instead of
-- RLS, every Hitchhiker action goes through an explicit SECURITY DEFINER
-- RPC that takes the access token as a plain parameter and validates it
-- itself — the same pattern this schema already uses for delete_user(),
-- mark_messages_read(), etc. The Flutter client calls these using the anon
-- key with no signed-in session. trip_hitchhikers itself has no anon/token
-- SELECT policy at all — token holders never query it directly, only
-- through the RPCs below, which look the token up server-side.
--
-- Safe to re-run: uses CREATE OR REPLACE / DROP POLICY IF EXISTS throughout.
-- Run in Supabase SQL editor before deploying the corresponding app build.
-- =============================================================================

-- ── 1. trip_hitchhikers ───────────────────────────────────────────────────────

create table if not exists public.trip_hitchhikers (
  id            uuid        primary key default gen_random_uuid(),
  itinerary_id  uuid        not null references public.itineraries(id) on delete cascade,
  -- First name / nickname only — deliberately no email, phone, or DOB column
  -- exists on this table. Do not add one; see the header comment above.
  display_name  text        not null check (char_length(trim(display_name)) between 1 and 60),
  access_token  uuid        not null default gen_random_uuid(),
  created_by    uuid        not null references auth.users(id) on delete cascade,
  created_at    timestamptz not null default now(),
  revoked_at    timestamptz
);

create unique index if not exists trip_hitchhikers_access_token_idx
  on public.trip_hitchhikers (access_token);
create index if not exists trip_hitchhikers_itinerary_id_idx
  on public.trip_hitchhikers (itinerary_id);

comment on table public.trip_hitchhikers is
  'Non-account trip collaborators (see stage45 header). Not a full account: '
  'no user_id, no auth.users row, no cross-trip identity. Access is by '
  'possession of access_token, not by auth.uid() — see this migration''s '
  'RPCs for the only sanctioned way to read/write on a Hitchhiker''s behalf.';

alter table public.trip_hitchhikers enable row level security;

drop policy if exists "trip_hitchhikers_captain_all" on public.trip_hitchhikers;

-- Only the trip's Captain (owner_id) can create/list/revoke Hitchhikers for
-- their own trip. Deliberately Captain-only, not extended to Crew (editors) —
-- matches the product decision that only the trip owner grants this access.
create policy "trip_hitchhikers_captain_all" on public.trip_hitchhikers
  for all
  using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id and i.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id and i.owner_id = auth.uid()
    )
  );

-- ── 2. itinerary_suggestions ─────────────────────────────────────────────────
-- Hitchhiker-authored itinerary suggestions live in their own table rather
-- than writing into itineraries.items directly — keeps every Hitchhiker
-- write fully isolated from the core itinerary model (owned/edited only by
-- Captain/Crew through the existing, unrestricted path) and gives the Captain
-- a simple review/accept/dismiss queue instead of unreviewed direct edits.

create table if not exists public.itinerary_suggestions (
  id                          uuid        primary key default gen_random_uuid(),
  itinerary_id                uuid        not null references public.itineraries(id) on delete cascade,
  title                       text        not null check (char_length(trim(title)) between 1 and 200),
  description                 text        check (description is null or char_length(description) <= 2000),
  suggested_by_hitchhiker_id  uuid        references public.trip_hitchhikers(id) on delete set null,
  -- Denormalised so the suggestion still reads sensibly ("Priya suggested
  -- this") even if the Hitchhiker row is later hard-deleted — normal
  -- revocation (revoked_at) leaves the row intact and doesn't need this.
  suggested_by_name           text        not null,
  status                      text        not null default 'pending'
                                          check (status in ('pending', 'accepted', 'dismissed')),
  created_at                  timestamptz not null default now()
);

create index if not exists itinerary_suggestions_itinerary_id_idx
  on public.itinerary_suggestions (itinerary_id, created_at desc);

alter table public.itinerary_suggestions enable row level security;

drop policy if exists "itinerary_suggestions_member_read" on public.itinerary_suggestions;
drop policy if exists "itinerary_suggestions_captain_update" on public.itinerary_suggestions;

-- Captain and Crew (existing itinerary-membership pattern, dual-key user_id/
-- userId per SEC-018) can read the suggestion queue.
create policy "itinerary_suggestions_member_read" on public.itinerary_suggestions
  for select using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where m->>'user_id' = auth.uid()::text or m->>'userId' = auth.uid()::text
          )
        )
    )
  );

-- Only the Captain can accept/dismiss (status transition). No client insert
-- policy — every row is written by hitchhiker_suggest_item() below.
create policy "itinerary_suggestions_captain_update" on public.itinerary_suggestions
  for update using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id and i.owner_id = auth.uid()
    )
  );

-- ── 3. messages: allow Hitchhiker-authored rows ──────────────────────────────

alter table public.messages
  alter column sender_id drop not null;

alter table public.messages
  add column if not exists hitchhiker_id uuid references public.trip_hitchhikers(id);

-- Exactly one of sender_id (Captain/Crew) / hitchhiker_id (Hitchhiker) must be
-- set — a message is always attributable to exactly one participant, never
-- both and never neither. Note: this means a Hitchhiker row must be revoked
-- (revoked_at), not hard-deleted, once it has authored messages — hard
-- deletion isn't exposed anywhere in this schema's RPC surface (only
-- revoke_hitchhiker below), so this constraint is never expected to
-- conflict with the FK's default ON DELETE behavior in normal operation.
alter table public.messages
  drop constraint if exists messages_sender_xor_hitchhiker;
alter table public.messages
  add constraint messages_sender_xor_hitchhiker
  check ((sender_id is not null) <> (hitchhiker_id is not null));

comment on column public.messages.hitchhiker_id is
  'Set instead of sender_id when this message was posted by a Hitchhiker '
  '(non-account collaborator, see stage45). Exactly one of sender_id/'
  'hitchhiker_id is set — see messages_sender_xor_hitchhiker.';

-- messages_owner_all / messages_member_read (stage2) already scope by
-- itinerary membership, not by sender — Hitchhiker-authored rows are
-- visible to Captain/Crew exactly like any other message, no RLS change
-- needed. Hitchhiker writes go through hitchhiker_send_message() below,
-- a SECURITY DEFINER RPC that bypasses RLS by design (same as every other
-- token-authenticated write in this migration), so no INSERT policy change
-- is needed there either.

-- ── 4. Captain-side management RPCs ───────────────────────────────────────────

create or replace function public.create_hitchhiker(
  p_itinerary_id uuid,
  p_display_name text
)
returns table (id uuid, access_token uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  _uid uuid := auth.uid();
  _name text := trim(coalesce(p_display_name, ''));
begin
  if _uid is null then
    raise exception 'Not authenticated';
  end if;
  if not exists (
    select 1 from public.itineraries i where i.id = p_itinerary_id and i.owner_id = _uid
  ) then
    raise exception 'Only the trip owner can add a Hitchhiker';
  end if;
  if char_length(_name) < 1 or char_length(_name) > 60 then
    raise exception 'Name must be 1-60 characters';
  end if;

  return query
    insert into public.trip_hitchhikers (itinerary_id, display_name, created_by)
    values (p_itinerary_id, _name, _uid)
    returning trip_hitchhikers.id, trip_hitchhikers.access_token;
end;
$$;

revoke all on function public.create_hitchhiker(uuid, text) from anon;
grant execute on function public.create_hitchhiker(uuid, text) to authenticated;

create or replace function public.revoke_hitchhiker(p_hitchhiker_id uuid)
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

  update public.trip_hitchhikers h
  set revoked_at = now()
  where h.id = p_hitchhiker_id
    and h.revoked_at is null
    and exists (
      select 1 from public.itineraries i
      where i.id = h.itinerary_id and i.owner_id = _uid
    );

  if not found then
    raise exception 'Hitchhiker not found, already revoked, or you do not own this trip';
  end if;
end;
$$;

revoke all on function public.revoke_hitchhiker(uuid) from anon;
grant execute on function public.revoke_hitchhiker(uuid) to authenticated;

-- Listing existing Hitchhikers for a trip needs no RPC — the Captain already
-- has direct SELECT via trip_hitchhikers_captain_all above (a normal
-- PostgREST query from the Flutter client, RLS-scoped like everything else
-- Captain/Crew do). Only token-holders (no session) need the RPC indirection.

-- ── 5. Hitchhiker-side RPCs (token-authenticated, no session) ───────────────
-- Granted to anon (not just authenticated) since a Hitchhiker client never
-- signs in — the Flutter app calls these using only the public anon key.

create or replace function public.hitchhiker_get_trip_view(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  _h record;
  _i record;
begin
  select * into _h from public.trip_hitchhikers
  where access_token = p_token and revoked_at is null;

  if _h is null then
    raise exception 'This collaborator link is no longer valid.';
  end if;

  select * into _i from public.itineraries where id = _h.itinerary_id;

  return jsonb_build_object(
    'hitchhiker_id', _h.id,
    'display_name', _h.display_name,
    'itinerary', jsonb_build_object(
      'id', _i.id,
      'title', _i.title,
      'description', _i.description,
      'start_date', _i.start_date,
      'end_date', _i.end_date,
      'status', _i.status
      -- Deliberately NOT the full itinerary row: `members`/`items` expose
      -- other travelers' identities and `expense_summary` is financial
      -- data. A Hitchhiker gets a minimal read-only summary, never the raw
      -- row Captain/Crew get via normal RLS.
    ),
    'messages', (
      select coalesce(jsonb_agg(row_to_json(t) order by t.created_at asc), '[]'::jsonb)
      from (
        select m.id, m.sender_name, m.content, m.created_at,
               (m.hitchhiker_id = _h.id) as is_you
        from public.messages m
        where m.itinerary_id = _h.itinerary_id
        order by m.created_at desc
        limit 100
      ) t
    ),
    'suggestions', (
      select coalesce(jsonb_agg(row_to_json(t) order by t.created_at desc), '[]'::jsonb)
      from (
        select s.id, s.title, s.description, s.suggested_by_name, s.status, s.created_at
        from public.itinerary_suggestions s
        where s.itinerary_id = _h.itinerary_id
      ) t
    )
  );
end;
$$;

revoke all on function public.hitchhiker_get_trip_view(uuid) from authenticated;
grant execute on function public.hitchhiker_get_trip_view(uuid) to anon, authenticated;

create or replace function public.hitchhiker_send_message(p_token uuid, p_content text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  _h record;
begin
  select * into _h from public.trip_hitchhikers
  where access_token = p_token and revoked_at is null;

  if _h is null then
    raise exception 'This collaborator link is no longer valid.';
  end if;
  if p_content is null or char_length(trim(p_content)) = 0 then
    raise exception 'Message cannot be empty';
  end if;
  if char_length(p_content) > 4000 then
    raise exception 'Message is too long';
  end if;

  insert into public.messages (itinerary_id, sender_id, hitchhiker_id, sender_name, content)
  values (_h.itinerary_id, null, _h.id, _h.display_name, p_content);
end;
$$;

revoke all on function public.hitchhiker_send_message(uuid, text) from authenticated;
grant execute on function public.hitchhiker_send_message(uuid, text) to anon, authenticated;

create or replace function public.hitchhiker_suggest_item(
  p_token uuid,
  p_title text,
  p_description text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  _h record;
begin
  select * into _h from public.trip_hitchhikers
  where access_token = p_token and revoked_at is null;

  if _h is null then
    raise exception 'This collaborator link is no longer valid.';
  end if;
  if p_title is null or char_length(trim(p_title)) = 0 then
    raise exception 'A title is required';
  end if;

  insert into public.itinerary_suggestions
    (itinerary_id, title, description, suggested_by_hitchhiker_id, suggested_by_name)
  values (
    _h.itinerary_id,
    trim(p_title),
    nullif(trim(coalesce(p_description, '')), ''),
    _h.id,
    _h.display_name
  );
end;
$$;

revoke all on function public.hitchhiker_suggest_item(uuid, text, text) from authenticated;
grant execute on function public.hitchhiker_suggest_item(uuid, text, text) to anon, authenticated;

-- Deliberately deferred (documented, not forgotten — same posture as
-- SEC-021's like/follow rate-limit deferral): no per-Hitchhiker rate limit
-- on send_message/suggest_item yet. access_token is a random UUID (122 bits
-- of entropy, not guessable) shared only with the specific person the
-- Captain invited, and is instantly revocable — the exposure window this
-- would protect against is small. Revisit if abuse is observed.

-- ── 6. Structural exclusion, not a checklist ─────────────────────────────────
-- No code change is needed to keep Hitchhikers out of itinerary_posts
-- (publishing/discovery), notification_preferences, push_tokens, xp_events,
-- or any marketing-email send path — every one of those tables has a hard
-- FK to auth.users(id)/profiles(id), and a Hitchhiker never has either. This
-- is enforced by the schema shape itself, not by scattered "if hitchhiker,
-- skip" checks that a future change could forget. Keep it that way: don't
-- add a user_id/profile_id to trip_hitchhikers.
