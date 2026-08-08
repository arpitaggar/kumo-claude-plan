-- =============================================================================
-- Stage 31 — Fix "infinite recursion detected in policy for relation
-- org_members" (Postgres error 42P17). Depends on stage28/29/30. Safe to
-- re-run.
-- =============================================================================
--
-- Root cause: several RLS policies (org_members' own SELECT/INSERT/UPDATE/
-- DELETE policies, plus organizations/itineraries/expenses/org_cost_fields*
-- policies that check org membership via `exists (select 1 from
-- public.org_members ...)`) queried org_members directly from *inside
-- another policy on org_members itself* — e.g. org_members_select's own
-- USING clause queries org_members to check membership. Postgres has to
-- apply org_members' RLS policies to evaluate that inner query too, which
-- means evaluating org_members_select again, forever. This wasn't a
-- performance problem that just happened to be slow — Postgres detects the
-- cycle and raises 42P17 outright, so every one of these policies has been
-- failing since stage28 shipped.
--
-- Fix: move every "is this user a member/admin of this org" check into a
-- SECURITY DEFINER function. A SECURITY DEFINER function runs as its
-- owner (the role that created it — the Supabase SQL editor's `postgres`
-- role, which has BYPASSRLS), so the query *inside* the function never
-- re-triggers org_members' own RLS, breaking the cycle. This is the same
-- pattern already used correctly elsewhere in this schema (e.g.
-- resolve_trip_cost_center_code, the guard_* trigger functions) — the bug
-- was specifically in the handful of policies that inlined the org_members
-- check directly instead of going through a function.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Helper functions
-- -----------------------------------------------------------------------------

create or replace function public.is_org_member(
  p_org_id  uuid,
  p_user_id uuid default auth.uid()
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.org_members
    where org_id = p_org_id and user_id = p_user_id
  );
$$;

grant execute on function public.is_org_member(uuid, uuid) to authenticated;

create or replace function public.is_org_admin(
  p_org_id  uuid,
  p_user_id uuid default auth.uid()
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.org_members
    where org_id = p_org_id and user_id = p_user_id and role in ('owner', 'admin')
  );
$$;

grant execute on function public.is_org_admin(uuid, uuid) to authenticated;

-- For org_cost_field_options / org_cost_field_sources, whose rows carry a
-- field_id, not an org_id directly — resolves the org via org_cost_fields
-- inside the same SECURITY DEFINER context, so that lookup never re-enters
-- org_cost_fields' or org_members' own RLS either.
create or replace function public.is_org_member_for_cost_field(
  p_field_id uuid,
  p_user_id  uuid default auth.uid()
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.org_cost_fields f
    where f.id = p_field_id and public.is_org_member(f.org_id, p_user_id)
  );
$$;

grant execute on function public.is_org_member_for_cost_field(uuid, uuid) to authenticated;

create or replace function public.is_org_admin_for_cost_field(
  p_field_id uuid,
  p_user_id  uuid default auth.uid()
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.org_cost_fields f
    where f.id = p_field_id and public.is_org_admin(f.org_id, p_user_id)
  );
$$;

grant execute on function public.is_org_admin_for_cost_field(uuid, uuid) to authenticated;

-- For expenses' org-admin review policies, which key off itinerary_id.
create or replace function public.is_org_admin_for_itinerary(
  p_itinerary_id uuid,
  p_user_id      uuid default auth.uid()
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.itineraries i
    where i.id = p_itinerary_id
      and i.org_id is not null
      and public.is_org_admin(i.org_id, p_user_id)
  );
$$;

grant execute on function public.is_org_admin_for_itinerary(uuid, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 2. org_members — the table where the recursion actually lives.
-- -----------------------------------------------------------------------------

drop policy if exists "org_members_select" on public.org_members;
create policy "org_members_select" on public.org_members
  for select using (
    user_id = auth.uid() or public.is_org_member(org_id)
  );

drop policy if exists "org_members_manage_insert" on public.org_members;
create policy "org_members_manage_insert" on public.org_members
  for insert with check (
    role in ('admin', 'member') and public.is_org_admin(org_id)
  );

drop policy if exists "org_members_manage_update" on public.org_members;
create policy "org_members_manage_update" on public.org_members
  for update
  using (role <> 'owner' and public.is_org_admin(org_id))
  with check (role in ('admin', 'member'));

drop policy if exists "org_members_manage_delete" on public.org_members;
create policy "org_members_manage_delete" on public.org_members
  for delete using (
    role <> 'owner' and public.is_org_admin(org_id)
  );

-- -----------------------------------------------------------------------------
-- 3. organizations
-- -----------------------------------------------------------------------------

drop policy if exists "organizations_select" on public.organizations;
create policy "organizations_select" on public.organizations
  for select using (
    owner_id = auth.uid() or public.is_org_member(id)
  );

-- -----------------------------------------------------------------------------
-- 4. itineraries
-- -----------------------------------------------------------------------------

drop policy if exists "itineraries_owner_all" on public.itineraries;
create policy "itineraries_owner_all" on public.itineraries
  for all
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and (org_id is null or public.is_org_member(org_id))
  );

drop policy if exists "org_admin_trip_visibility_select" on public.itineraries;
create policy "org_admin_trip_visibility_select" on public.itineraries
  for select using (
    org_id is not null and public.is_org_admin(org_id)
  );

-- -----------------------------------------------------------------------------
-- 5. expenses
-- -----------------------------------------------------------------------------

drop policy if exists "expenses_org_admin_review_select" on public.expenses;
create policy "expenses_org_admin_review_select" on public.expenses
  for select using (
    is_official = true
    and approval_status <> 'not_submitted'
    and public.is_org_admin_for_itinerary(itinerary_id)
  );

drop policy if exists "expenses_org_admin_review_update" on public.expenses;
create policy "expenses_org_admin_review_update" on public.expenses
  for update
  using (
    is_official = true
    and approval_status <> 'not_submitted'
    and public.is_org_admin_for_itinerary(itinerary_id)
  )
  with check (
    is_official = true and public.is_org_admin_for_itinerary(itinerary_id)
  );

-- -----------------------------------------------------------------------------
-- 6. org_cost_fields / org_cost_field_options / org_cost_field_sources
-- -----------------------------------------------------------------------------

drop policy if exists "org_cost_fields_member_select" on public.org_cost_fields;
create policy "org_cost_fields_member_select" on public.org_cost_fields
  for select using (public.is_org_member(org_id));

drop policy if exists "org_cost_fields_admin_write" on public.org_cost_fields;
create policy "org_cost_fields_admin_write" on public.org_cost_fields
  for all
  using (public.is_org_admin(org_id))
  with check (public.is_org_admin(org_id));

drop policy if exists "org_cost_field_options_member_select" on public.org_cost_field_options;
create policy "org_cost_field_options_member_select" on public.org_cost_field_options
  for select using (public.is_org_member_for_cost_field(field_id));

drop policy if exists "org_cost_field_options_admin_write" on public.org_cost_field_options;
create policy "org_cost_field_options_admin_write" on public.org_cost_field_options
  for all
  using (public.is_org_admin_for_cost_field(field_id))
  with check (public.is_org_admin_for_cost_field(field_id));

drop policy if exists "org_cost_field_sources_member_select" on public.org_cost_field_sources;
create policy "org_cost_field_sources_member_select" on public.org_cost_field_sources
  for select using (public.is_org_member_for_cost_field(generated_field_id));

drop policy if exists "org_cost_field_sources_admin_write" on public.org_cost_field_sources;
create policy "org_cost_field_sources_admin_write" on public.org_cost_field_sources
  for all
  using (public.is_org_admin_for_cost_field(generated_field_id))
  with check (public.is_org_admin_for_cost_field(generated_field_id));
