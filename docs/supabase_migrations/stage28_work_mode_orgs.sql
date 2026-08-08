-- =============================================================================
-- Stage 28 — Work mode: organizations, org membership, org-scoped trips
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================
--
-- Turns docs/ARCHITECTURE.md's "Future B2B Scalability Plan" sketch (never
-- implemented — no organizations/org_members table, no org_id column existed
-- anywhere before this migration) into a real, minimal foundation: a trip can
-- be tagged as belonging to an organization, and an org admin gets narrow
-- oversight of org-tagged trips (that they exist — title/dates/status only).
-- It deliberately does NOT grant blanket access to a trip's content (chat,
-- packing lists, itemized expenses stay governed by the trip's own `members`
-- array exactly as today) — see stage29_expense_approval_workflow.sql for the
-- one precise, opt-in exception (a traveler's own submitted expenses).
--
-- Role vocabulary is `owner/admin/member` — deliberately NOT the architecture
-- doc's `owner/admin/manager/employee`. `manager` only means something once a
-- policy/approval-routing engine exists to hang it off; adding a role with no
-- caller is speculative surface area. `admin` is the role that can review
-- expense submissions (stage29) and manage the org roster.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. organizations
--    No subscription_tier column (no billing integration exists to hang it
--    off — mirrors the roadmap's own "Virtual Debit Card... requires legal/
--    compliance review, deferred" reasoning for anything payment-adjacent).
-- -----------------------------------------------------------------------------

create table if not exists public.organizations (
  id         uuid        primary key default gen_random_uuid(),
  name       text        not null,
  slug       text        not null unique,
  owner_id   uuid        not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- RLS on organizations is enabled further down (after org_members exists —
-- organizations_select below needs to reference it, and CREATE POLICY
-- resolves table references at creation time, not at query time).

-- -----------------------------------------------------------------------------
-- 2. org_members
--    role='owner' is never settable through client INSERT/UPDATE (with check
--    below excludes it) — the owner's own row is created exclusively by
--    handle_new_organization_owner() when the org is created (§3), the same
--    "auto-provision via a SECURITY DEFINER trigger, no client round-trip"
--    pattern trip_email_aliases already uses. That, plus disallowing delete
--    of a role='owner' row, is what keeps ownership transfer out of scope
--    without needing extra guard machinery.
-- -----------------------------------------------------------------------------

create table if not exists public.org_members (
  id        uuid        primary key default gen_random_uuid(),
  org_id    uuid        not null references public.organizations(id) on delete cascade,
  user_id   uuid        not null references auth.users(id) on delete cascade,
  user_name text        not null default '',
  role      text        not null default 'member'
                        check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz not null default now(),
  unique (org_id, user_id)
);

comment on column public.org_members.user_name is
  'Denormalised display name, captured at invite time — same convention as '
  'messages.sender_name / expenses.payer_name / itineraries.members[].userName '
  'throughout this schema, rather than relying on a client-side join back to '
  'profiles (org_members.user_id -> auth.users, not directly -> profiles, so '
  'PostgREST cannot auto-embed profiles here anyway).';

create index if not exists org_members_user_id_idx on public.org_members (user_id);

-- ─── organizations RLS (deferred from §1 — needs org_members to exist) ──────

alter table public.organizations enable row level security;

drop policy if exists "organizations_select"      on public.organizations;
drop policy if exists "organizations_insert"      on public.organizations;
drop policy if exists "organizations_owner_write" on public.organizations;
drop policy if exists "organizations_owner_delete" on public.organizations;

create policy "organizations_select" on public.organizations
  for select using (
    owner_id = auth.uid()
    or exists (
      select 1 from public.org_members om
      where om.org_id = organizations.id and om.user_id = auth.uid()
    )
  );

-- Any authenticated user may create an organization (becomes its owner).
create policy "organizations_insert" on public.organizations
  for insert with check (owner_id = auth.uid());

-- Ownership transfer / self-serve deletion flows are out of scope for now
-- (see this stage's header) — the owner can still update/delete directly.
create policy "organizations_owner_write" on public.organizations
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "organizations_owner_delete" on public.organizations
  for delete using (owner_id = auth.uid());

-- ─── org_members RLS ─────────────────────────────────────────────────────────

alter table public.org_members enable row level security;

drop policy if exists "org_members_select"        on public.org_members;
drop policy if exists "org_members_manage_insert" on public.org_members;
drop policy if exists "org_members_manage_update" on public.org_members;
drop policy if exists "org_members_manage_delete" on public.org_members;

-- Any member of the org can see its own roster (including their own row).
create policy "org_members_select" on public.org_members
  for select using (
    user_id = auth.uid()
    or exists (
      select 1 from public.org_members om
      where om.org_id = org_members.org_id and om.user_id = auth.uid()
    )
  );

-- Owner/admin can add members — never as 'owner' (see header comment).
create policy "org_members_manage_insert" on public.org_members
  for insert with check (
    role in ('admin', 'member')
    and exists (
      select 1 from public.org_members om
      where om.org_id = org_members.org_id
        and om.user_id = auth.uid()
        and om.role in ('owner', 'admin')
    )
  );

-- Owner/admin can change a member's role between admin/member — the owner's
-- own row (role = 'owner', checked against the OLD row) can never be touched
-- this way.
create policy "org_members_manage_update" on public.org_members
  for update
  using (
    role <> 'owner'
    and exists (
      select 1 from public.org_members om
      where om.org_id = org_members.org_id
        and om.user_id = auth.uid()
        and om.role in ('owner', 'admin')
    )
  )
  with check (role in ('admin', 'member'));

-- Owner/admin can remove a member — again, never the owner's own row.
create policy "org_members_manage_delete" on public.org_members
  for delete using (
    role <> 'owner'
    and exists (
      select 1 from public.org_members om
      where om.org_id = org_members.org_id
        and om.user_id = auth.uid()
        and om.role in ('owner', 'admin')
    )
  );

-- -----------------------------------------------------------------------------
-- 3. Auto-provision the owner's own org_members row on org creation — no
--    client round-trip, mirrors handle_new_itinerary_email_alias exactly.
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_organization_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _owner_name text;
begin
  select coalesce(display_name, '') into _owner_name
  from public.profiles where id = new.owner_id;

  insert into public.org_members (org_id, user_id, user_name, role)
  values (new.id, new.owner_id, coalesce(_owner_name, ''), 'owner')
  on conflict (org_id, user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_organization_created on public.organizations;
create trigger on_organization_created
  after insert on public.organizations
  for each row execute function public.handle_new_organization_owner();

-- -----------------------------------------------------------------------------
-- 4. itineraries.org_id — nullable, null = personal trip. Same additive,
--    zero-backfill treatment as theme_key/origin_post_id in earlier stages.
-- -----------------------------------------------------------------------------

alter table public.itineraries
  add column if not exists org_id uuid references public.organizations(id) on delete set null;
  -- on delete set null, not cascade: deleting an org must never delete a
  -- trip, only un-scope it — same "personal data survives" instinct as
  -- delete_user()'s FK choices in stage23.

create index if not exists itineraries_org_id_idx
  on public.itineraries (org_id) where org_id is not null;

-- itineraries_owner_all's `with check` now also validates that an org_id
-- being set belongs to an org the (owner) caller actually belongs to. This
-- is the sole enforcement path for INSERT (the only policy that allows
-- insert); for UPDATE it's reinforced by a trigger below rather than relied
-- on alone, because multiple permissive policies' WITH CHECK clauses are
-- OR'd together in Postgres RLS — an owner who also happens to hold an
-- 'editor' entry in their own trip's members array could otherwise satisfy
-- itineraries_member_update's WITH CHECK instead and bypass this one.
drop policy if exists "itineraries_owner_all" on public.itineraries;
create policy "itineraries_owner_all" on public.itineraries
  for all
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and (
      org_id is null
      or exists (
        select 1 from public.org_members om
        where om.org_id = itineraries.org_id and om.user_id = auth.uid()
      )
    )
  );

-- itineraries_member_select / itineraries_member_update (per-trip membership,
-- unrelated to org_id) are untouched — see the audit note in §6 below.

-- Authoritative guard for UPDATE (see comment above): only the trip owner may
-- change org_id at all, and only to an org they belong to. Fires regardless
-- of which RLS policy let the UPDATE through.
create or replace function public.guard_org_id_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.org_id is distinct from old.org_id then
    if old.owner_id <> auth.uid() then
      raise exception 'Only the trip owner may change this trip''s organization';
    end if;
    if new.org_id is not null and not exists (
      select 1 from public.org_members om
      where om.org_id = new.org_id and om.user_id = auth.uid()
    ) then
      raise exception 'You must belong to an organization to tag a trip with it';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_org_id_change on public.itineraries;
create trigger guard_org_id_change
  before update on public.itineraries
  for each row execute function public.guard_org_id_change();

-- -----------------------------------------------------------------------------
-- 5. Org admin oversight — additive SELECT only. An org admin/owner can see
--    that an org-tagged trip exists (title, dates, status, top-line
--    expense_summary — whatever's a column on this row) but this is row
--    visibility, not a grant into the trip's members-gated content. Postgres
--    RLS OR's permissive policies together, so this only ever *adds*
--    visibility on top of itineraries_member_select, never replaces it.
-- -----------------------------------------------------------------------------

drop policy if exists "org_admin_trip_visibility_select" on public.itineraries;
create policy "org_admin_trip_visibility_select" on public.itineraries
  for select using (
    org_id is not null
    and exists (
      select 1 from public.org_members om
      where om.org_id = itineraries.org_id
        and om.user_id = auth.uid()
        and om.role in ('owner', 'admin')
    )
  );

-- -----------------------------------------------------------------------------
-- 6. Audit: every other itinerary-scoped table resolves membership by
--    joining back to itineraries.members, which org_id never touches — so
--    none of these need any policy change for org_id to work correctly:
--    ratings, expenses, messages, pending_invitations, trip_segments,
--    message_attachments, trip_email_aliases, trip_email_forward_log.
--    (expenses DOES get new columns + a policy in
--    stage29_expense_approval_workflow.sql — that's the one deliberate,
--    narrow exception to "org_id doesn't touch per-trip content", and it's
--    scoped to a traveler's own submitted expenses only, never blanket.)
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- 7. packing_items — unrelated bug fix, found while auditing §6: these four
--    policies were never migrated off the pre-stage12 `@>` containment check
--    (stage5_packing.sql), so they only recognize camelCase 'userId' members,
--    not the Flutter client's snake_case 'user_id' — the exact bug stage12/13
--    already fixed everywhere else. Replacing with the canonical EXISTS +
--    jsonb_array_elements dual-key pattern. The delete policy (creator-or-
--    owner) isn't buggy and is left untouched.
-- -----------------------------------------------------------------------------

drop policy if exists "trip members can view packing items" on public.packing_items;
drop policy if exists "trip members can insert packing items" on public.packing_items;
drop policy if exists "trip members can update packing items" on public.packing_items;

create policy "trip members can view packing items"
  on public.packing_items for select
  using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where m->>'user_id' = auth.uid()::text
               or m->>'userId'  = auth.uid()::text
          )
        )
    )
  );

create policy "trip members can insert packing items"
  on public.packing_items for insert
  with check (
    added_by_id = auth.uid()
    and exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where m->>'user_id' = auth.uid()::text
               or m->>'userId'  = auth.uid()::text
          )
        )
    )
  );

create policy "trip members can update packing items"
  on public.packing_items for update
  using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where m->>'user_id' = auth.uid()::text
               or m->>'userId'  = auth.uid()::text
          )
        )
    )
  );
