-- =============================================================================
-- Stage 23 — Security & privacy hardening (2026-08 audit remediation)
-- Fixes SEC-001, SEC-003, SEC-004, SEC-005, SEC-009, SEC-010, SEC-012,
-- SEC-017, SEC-018, SEC-021 from docs/SECURITY_AUDIT.md. Safe to re-run:
-- uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS throughout.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- [SEC-009] Per-user rate limit for the generate-itinerary Edge Function,
-- which otherwise has no cap on how many paid Anthropic API calls a single
-- account can trigger. The function itself (supabase/functions/
-- generate-itinerary/index.ts) checks this table before calling Anthropic.
-- -----------------------------------------------------------------------------

create table if not exists public.generation_requests (
  id         uuid        primary key default gen_random_uuid(),
  user_id    uuid        not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists generation_requests_user_id_created_at_idx
  on public.generation_requests (user_id, created_at desc);

alter table public.generation_requests enable row level security;

-- No client access at all — only the service-role Edge Function reads/writes
-- this table directly (it authenticates the caller itself via their JWT).
drop policy if exists "generation_requests_none" on public.generation_requests;

-- -----------------------------------------------------------------------------
-- [SEC-001] Prevent a non-owner from changing itineraries.owner_id.
--
-- itineraries_member_update's `with check` only validates the PROPOSED row,
-- so an editor can UPDATE owner_id to their own uid and satisfy the check
-- trivially. RLS can't see OLD vs NEW here — a BEFORE UPDATE trigger can.
-- -----------------------------------------------------------------------------

create or replace function public.prevent_unauthorized_owner_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_id is distinct from old.owner_id
     and old.owner_id <> auth.uid() then
    raise exception 'Only the current owner may transfer ownership of this trip';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_owner_id_change on public.itineraries;
create trigger guard_owner_id_change
  before update on public.itineraries
  for each row execute function public.prevent_unauthorized_owner_change();

-- -----------------------------------------------------------------------------
-- [SEC-005] Prevent a non-owner from mutating other members' entries in the
-- `members` JSONB array (only their own entry is theirs to touch).
--
-- Same root cause as SEC-001: `members` is one mutable blob the caller fully
-- controls in a single UPDATE, and itineraries_member_update never checks
-- that entries belonging to OTHER users are left untouched.
-- -----------------------------------------------------------------------------

create or replace function public.guard_members_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _uid uuid := auth.uid();
begin
  if old.owner_id = _uid then
    return new; -- the real owner may always manage membership freely
  end if;

  if exists (
    select 1
    from jsonb_array_elements(old.members) as m
    where not (m->>'user_id' = _uid::text or m->>'userId' = _uid::text)
      and not (new.members @> jsonb_build_array(m))
  ) then
    raise exception 'Only the trip owner may add, remove, or change other members';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_members_mutation on public.itineraries;
create trigger guard_members_mutation
  before update on public.itineraries
  for each row execute function public.guard_members_mutation();

-- -----------------------------------------------------------------------------
-- [SEC-003] Fix GDPR right-to-erasure: delete_user() currently rolls back
-- with a foreign-key violation for any user who has ever paid an expense,
-- added a packing item, or left a rating, because those three FKs (unlike
-- every other auth.users(id) FK in this schema) have no ON DELETE action.
-- -----------------------------------------------------------------------------

alter table public.expenses
  drop constraint if exists expenses_payer_id_fkey,
  add constraint expenses_payer_id_fkey
    foreign key (payer_id) references auth.users(id) on delete cascade;

alter table public.packing_items
  drop constraint if exists packing_items_added_by_id_fkey,
  add constraint packing_items_added_by_id_fkey
    foreign key (added_by_id) references auth.users(id) on delete cascade;

alter table public.ratings
  drop constraint if exists ratings_user_id_fkey,
  add constraint ratings_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete cascade;

-- -----------------------------------------------------------------------------
-- [SEC-004] profiles_select currently grants full-row read (bio, city,
-- country, email, ...) to ANY authenticated user unconditionally —
-- profile_visibility = 'private' has no server-side effect at all.
--
-- Fix widens beyond the audit's literal "own row or public" suggestion to
-- also allow is_searchable = true rows, because searchByName() (used by
-- "invite by name" on the trip invite screen) depends on being able to read
-- discoverable-but-not-necessarily-"public" profiles. A user is only fully
-- hidden once they've turned off BOTH profile_visibility and is_searchable.
-- -----------------------------------------------------------------------------

drop policy if exists "profiles_select" on public.profiles;

create policy "profiles_select" on public.profiles
  for select using (
    auth.uid() = id
    or profile_visibility = 'public'
    or is_searchable = true
  );

-- -----------------------------------------------------------------------------
-- [SEC-010] mark_messages_read() is SECURITY DEFINER (bypasses RLS by design,
-- since it needs to append to read_by/message_reads across all of a trip's
-- messages) but never checked the caller is actually a member of the trip.
-- -----------------------------------------------------------------------------

create or replace function public.mark_messages_read(p_itinerary_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.itineraries i
    where i.id = p_itinerary_id
      and (
        i.owner_id = auth.uid()
        or exists (
          select 1 from jsonb_array_elements(i.members) as m
          where m->>'user_id' = auth.uid()::text or m->>'userId' = auth.uid()::text
        )
      )
  ) then
    raise exception 'Not a member of this itinerary';
  end if;

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

-- -----------------------------------------------------------------------------
-- [SEC-018] message_attachments_member_read still uses the pre-stage13
-- camelCase-only ('userId') containment check, so a Flutter-added member
-- (snake_case 'user_id') is incorrectly denied read access to attachments on
-- a chat they otherwise belong to. Fails closed (not an exposure), but is a
-- regression against the dual-key pattern every other policy in this schema
-- already uses.
-- -----------------------------------------------------------------------------

drop policy if exists "message_attachments_member_read" on public.message_attachments;

create policy "message_attachments_member_read" on public.message_attachments
  for select using (
    exists (
      select 1 from public.messages m
      join public.itineraries i on i.id = m.itinerary_id
      where m.id = message_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as mem
            where mem->>'user_id' = auth.uid()::text or mem->>'userId' = auth.uid()::text
          )
        )
    )
  );

-- -----------------------------------------------------------------------------
-- [SEC-012] GDPR Art. 20 / CCPA data-portability RPC. delete_user() already
-- implements the right to erasure; nothing implemented the right to an
-- export until now. Scoped entirely to auth.uid(), same trust pattern as
-- delete_user().
-- -----------------------------------------------------------------------------

create or replace function public.export_own_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  _uid uuid := auth.uid();
begin
  return jsonb_build_object(
    'profile', (
      select to_jsonb(p) from public.profiles p where p.id = _uid
    ),
    'itineraries', (
      select coalesce(jsonb_agg(to_jsonb(i)), '[]'::jsonb)
      from public.itineraries i where i.owner_id = _uid
    ),
    'expenses', (
      select coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb)
      from public.expenses e where e.payer_id = _uid
    ),
    'packing_items', (
      select coalesce(jsonb_agg(to_jsonb(pk)), '[]'::jsonb)
      from public.packing_items pk where pk.added_by_id = _uid
    ),
    'ratings', (
      select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
      from public.ratings r where r.user_id = _uid
    ),
    'messages_sent', (
      select coalesce(jsonb_agg(to_jsonb(msg)), '[]'::jsonb)
      from public.messages msg where msg.sender_id = _uid
    ),
    'published_posts', (
      select coalesce(jsonb_agg(to_jsonb(pp)), '[]'::jsonb)
      from public.itinerary_posts pp where pp.author_id = _uid
    ),
    'following', (
      select coalesce(jsonb_agg(f.followee_id), '[]'::jsonb)
      from public.follows f where f.follower_id = _uid
    ),
    'followers', (
      select coalesce(jsonb_agg(f.follower_id), '[]'::jsonb)
      from public.follows f where f.followee_id = _uid
    )
  );
end;
$$;

revoke all on function public.export_own_data() from anon;
grant execute on function public.export_own_data() to authenticated;

-- -----------------------------------------------------------------------------
-- [SEC-021] Minimal abuse guard on the public feed's write-heaviest action.
-- Full rate limiting for likes/follows is deferred (Low severity, and both
-- are already bounded by their own PK uniqueness — you can't like/follow the
-- same target twice); this closes the cheapest script-spam vector (mass
-- publishing) with a single per-author cooldown.
-- -----------------------------------------------------------------------------

create or replace function public.guard_publish_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.itinerary_posts
    where author_id = new.author_id
      and created_at > now() - interval '30 seconds'
  ) then
    raise exception 'Please wait a moment before publishing again';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_publish_rate_limit on public.itinerary_posts;
create trigger guard_publish_rate_limit
  before insert on public.itinerary_posts
  for each row execute function public.guard_publish_rate_limit();

-- -----------------------------------------------------------------------------
-- [SEC-017] New users should start with chat push previews OFF (privacy by
-- default), not on. Only changes the column default for future signups —
-- existing users' own choice is left untouched.
-- -----------------------------------------------------------------------------

alter table public.profiles
  alter column push_message_preview_enabled set default false;
