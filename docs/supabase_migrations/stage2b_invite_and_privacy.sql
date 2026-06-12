-- =============================================================================
-- Stage 2b — Invite & Privacy migrations
-- Run after stage2_profiles_and_messages.sql
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Add discoverability flag to profiles
-- -----------------------------------------------------------------------------

alter table public.profiles
  add column if not exists is_searchable boolean not null default true;

-- Users can update their own searchability setting
-- (the existing profiles_update policy already covers this since it allows
--  any update where auth.uid() = id, so no new policy is needed)


-- -----------------------------------------------------------------------------
-- 2. pending_invitations
--    Stores invites sent to emails that don't yet have a Kumo account,
--    OR registered users who haven't been added yet (rare, belt-and-suspenders).
--    When a new user signs up, the trigger auto-joins any matching invitations.
-- -----------------------------------------------------------------------------

create table if not exists public.pending_invitations (
  id             uuid        primary key default gen_random_uuid(),
  itinerary_id   uuid        not null references public.itineraries(id) on delete cascade,
  invited_email  text        not null,
  invited_by     uuid        not null references auth.users(id) on delete cascade,
  role           text        not null default 'viewer'
                             check (role in ('viewer', 'editor')),
  created_at     timestamptz not null default now(),
  unique (itinerary_id, invited_email)
);

alter table public.pending_invitations enable row level security;

drop policy if exists "pending_invitations_owner"        on public.pending_invitations;
drop policy if exists "pending_invitations_invited_read" on public.pending_invitations;

-- Itinerary owner can manage invitations for their trips
create policy "pending_invitations_owner" on public.pending_invitations
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

-- Invited user can read their own pending invitations (by email)
create policy "pending_invitations_invited_read" on public.pending_invitations
  for select using (
    invited_email = (
      select email from public.profiles where id = auth.uid()
    )
  );


-- -----------------------------------------------------------------------------
-- 3. Extend handle_new_user trigger to auto-join pending invitations
--    When a user signs up, if their email has pending invitations, they are
--    added to those itineraries immediately.
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  inv record;
  new_member jsonb;
begin
  -- Create profile row
  insert into public.profiles (id, display_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', ''),
    new.email
  )
  on conflict (id) do nothing;

  -- Auto-join any pending invitations for this email
  for inv in
    select * from public.pending_invitations
    where lower(invited_email) = lower(new.email)
  loop
    new_member := jsonb_build_object(
      'userId',   new.id::text,
      'userName', coalesce(new.raw_user_meta_data->>'display_name', new.email),
      'role',     inv.role,
      'joinedAt', now()
    );

    update public.itineraries
    set members = members || new_member
    where id = inv.itinerary_id
      and not (members @> jsonb_build_array(
                 jsonb_build_object('userId', new.id::text)
               ));

    delete from public.pending_invitations where id = inv.id;
  end loop;

  return new;
end;
$$;
-- Note: the trigger on_auth_user_created already exists from the previous
-- migration and calls this function — recreating the function is sufficient.


-- -----------------------------------------------------------------------------
-- 4. Backfill is_searchable for existing profiles (safe no-op if already set)
-- -----------------------------------------------------------------------------

update public.profiles set is_searchable = true where is_searchable is null;
