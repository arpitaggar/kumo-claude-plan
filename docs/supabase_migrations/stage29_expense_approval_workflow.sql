-- =============================================================================
-- Stage 29 — Expense official-flagging + submit/approve/reject workflow
-- Depends on stage28_work_mode_orgs.sql (org_members, itineraries.org_id).
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================
--
-- A traveler's expenses on an org-tagged trip are a mix of personal and
-- work spending. This lets them flag individual expenses as `is_official`
-- (one at a time, or all at once) and submit some or all of them for an org
-- admin to approve or reject — the org never gets blanket visibility into a
-- trip's expenses, only the ones a traveler actually chose to submit. This
-- is the one deliberate, narrow exception to stage28 §6's "org_id doesn't
-- touch per-trip content" audit note.
-- =============================================================================

alter table public.expenses
  add column if not exists is_official      boolean     not null default false,
  add column if not exists approval_status  text        not null default 'not_submitted'
                                             check (approval_status in
                                               ('not_submitted', 'pending', 'approved', 'rejected')),
  add column if not exists notes            text,
  add column if not exists rejection_reason text,
  add column if not exists submitted_at     timestamptz,
  add column if not exists reviewed_at      timestamptz,
  add column if not exists reviewed_by      uuid references auth.users(id);

-- -----------------------------------------------------------------------------
-- The traveler submits/resubmits their own expense — no update policy on
-- expenses exists yet at all (the app currently only adds/deletes them), so
-- this is new, not a widening of an existing one. Scoped to the payer, same
-- "your own spending is yours to edit" boundary as expenses' delete policy.
-- -----------------------------------------------------------------------------

drop policy if exists "expenses_payer_update" on public.expenses;
create policy "expenses_payer_update" on public.expenses
  for update
  using (payer_id = auth.uid())
  with check (payer_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Org admin/owner review access — additive, and precise: only expenses that
-- are BOTH flagged official AND actually submitted (approval_status <>
-- 'not_submitted'). A traveler's personal or not-yet-submitted expenses are
-- never visible here, regardless of org_id.
-- -----------------------------------------------------------------------------

drop policy if exists "expenses_org_admin_review_select" on public.expenses;
create policy "expenses_org_admin_review_select" on public.expenses
  for select using (
    is_official = true
    and approval_status <> 'not_submitted'
    and exists (
      select 1 from public.itineraries i
      join public.org_members om on om.org_id = i.org_id
      where i.id = expenses.itinerary_id
        and om.user_id = auth.uid()
        and om.role in ('owner', 'admin')
    )
  );

drop policy if exists "expenses_org_admin_review_update" on public.expenses;
create policy "expenses_org_admin_review_update" on public.expenses
  for update
  using (
    is_official = true
    and approval_status <> 'not_submitted'
    and exists (
      select 1 from public.itineraries i
      join public.org_members om on om.org_id = i.org_id
      where i.id = expenses.itinerary_id
        and om.user_id = auth.uid()
        and om.role in ('owner', 'admin')
    )
  )
  with check (
    is_official = true
    and exists (
      select 1 from public.itineraries i
      join public.org_members om on om.org_id = i.org_id
      where i.id = expenses.itinerary_id
        and om.user_id = auth.uid()
        and om.role in ('owner', 'admin')
    )
  );

-- -----------------------------------------------------------------------------
-- Column-level guard RLS alone can't express: expenses_payer_update grants
-- the payer general UPDATE rights on their own row (so they can fix a typo
-- before submitting, same as any owner-editable row elsewhere in this
-- schema) — without this trigger, that same policy would let them set
-- approval_status = 'approved' on themselves directly. Only an org
-- admin/owner may move status to approved/rejected; moving it to pending
-- (submit or resubmit) is the traveler's own action and is untouched here.
-- -----------------------------------------------------------------------------

create or replace function public.guard_expense_review_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.approval_status in ('approved', 'rejected')
     and new.approval_status is distinct from old.approval_status
     and not exists (
       select 1 from public.itineraries i
       join public.org_members om on om.org_id = i.org_id
       where i.id = new.itinerary_id
         and om.user_id = auth.uid()
         and om.role in ('owner', 'admin')
     )
  then
    raise exception 'Only an organization admin may approve or reject an expense';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_expense_review_fields on public.expenses;
create trigger guard_expense_review_fields
  before update on public.expenses
  for each row execute function public.guard_expense_review_fields();
