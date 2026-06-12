-- =============================================================================
-- Stage 2 migrations — run in order in Supabase SQL editor
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. profiles
--    One row per auth user. Readable by all authenticated users so the invite
--    flow can look up a user by email. Auto-created via trigger on signup.
-- -----------------------------------------------------------------------------

create table if not exists public.profiles (
  id           uuid        primary key references auth.users(id) on delete cascade,
  display_name text        not null default '',
  email        text        not null,
  avatar_url   text,
  created_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select" on public.profiles;
drop policy if exists "profiles_update" on public.profiles;

-- Any authenticated user can look up any profile (needed for invite-by-email)
create policy "profiles_select" on public.profiles
  for select using (auth.role() = 'authenticated');

-- Only the owner can update their own profile
create policy "profiles_update" on public.profiles
  for update
  using     (auth.uid() = id)
  with check (auth.uid() = id);

-- Trigger: create profile row automatically when a new user signs up
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
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- -----------------------------------------------------------------------------
-- 2. messages
--    One row per chat message, scoped to an itinerary. Access is controlled by
--    membership: itinerary owners and members can read and write.
--
--    RLS reuses the same JSONB-contains pattern as the itinerary table so that
--    no join table is needed at this stage.
-- -----------------------------------------------------------------------------

create table if not exists public.messages (
  id             uuid        primary key default gen_random_uuid(),
  itinerary_id   uuid        not null references public.itineraries(id) on delete cascade,
  sender_id      uuid        not null references auth.users(id) on delete cascade,
  sender_name    text        not null default '',
  content        text        not null check (char_length(content) between 1 and 4000),
  created_at     timestamptz not null default now()
);

alter table public.messages enable row level security;

drop policy if exists "messages_owner_all"      on public.messages;
drop policy if exists "messages_member_read"    on public.messages;
drop policy if exists "messages_member_insert"  on public.messages;

-- Owner of the itinerary can read and write
create policy "messages_owner_all" on public.messages
  for all
  using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and i.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and i.owner_id = auth.uid()
    )
  );

-- Members listed in the JSONB array can read and insert (not delete)
create policy "messages_member_read" on public.messages
  for select using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and i.members @> jsonb_build_array(
              jsonb_build_object('userId', auth.uid()::text)
            )
    )
  );

create policy "messages_member_insert" on public.messages
  for insert with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or i.members @> jsonb_build_array(
               jsonb_build_object('userId', auth.uid()::text)
             )
        )
    )
  );

-- Enable Realtime for live chat
alter publication supabase_realtime add table public.messages;
