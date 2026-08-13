-- =============================================================================
-- Stage 39 — Per-department approval-routing thresholds + feature-flag
-- overrides.
--
-- Second of two follow-ups explicitly flagged as deferred in the stage35
-- join-code work (the other, a kumo://join deep link, is stage38's sibling
-- — see docs/Checklist.md). Builds on org_members.cost_field_option_id
-- (stage35) — this pass only gets people into the right org + department;
-- this stage is what department membership actually *does*.
--
-- Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Approval-routing thresholds — an expense below the threshold
--    auto-approves on submit instead of landing in the admin review queue.
--    Two levels: a department-specific override
--    (org_cost_field_options.approval_threshold) takes precedence over the
--    org-wide default (organizations.default_approval_threshold); either or
--    both being null means "no threshold, everything needs manual review"
--    — today's behavior, preserved as the default.
-- -----------------------------------------------------------------------------

alter table public.organizations
  add column if not exists default_approval_threshold numeric;

alter table public.org_cost_field_options
  add column if not exists approval_threshold numeric;

alter table public.expenses
  add column if not exists auto_approved boolean not null default false;

comment on column public.expenses.auto_approved is
  'Set only by guard_expense_review_fields() when a submission lands under '
  'the submitter''s department (or org-default) approval threshold — never '
  'trust a client-supplied value for this column, see that function.';

-- Owner-only today (organizations has no admin-scoped update policy — see
-- organizations_owner_write, stage28), so this is an RPC rather than
-- widening that policy to admins for one column.
create or replace function public.set_org_default_approval_threshold(
  p_org_id    uuid,
  p_threshold numeric
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_org_admin(p_org_id) then
    raise exception 'Only an organization admin may set the approval threshold';
  end if;
  if p_threshold is not null and p_threshold < 0 then
    raise exception 'Threshold must be non-negative';
  end if;

  update public.organizations
    set default_approval_threshold = p_threshold
    where id = p_org_id;
end;
$$;

revoke all on function public.set_org_default_approval_threshold(uuid, numeric) from anon;
grant execute on function public.set_org_default_approval_threshold(uuid, numeric) to authenticated;

-- org_cost_field_options.approval_threshold, by contrast, needs no RPC —
-- org_cost_field_options_admin_write (stage31) already grants admins full
-- row control, so a plain client update covers this new column too.

-- -----------------------------------------------------------------------------
-- Auto-approval enforcement — folded into the existing
-- guard_expense_review_fields() trigger (stage29) rather than a second
-- BEFORE UPDATE trigger on the same table: Postgres fires same-table BEFORE
-- triggers in alphabetical-by-name order, and a separate
-- "auto_approve_expense_submission" trigger would run before this one
-- (a < g) and hand it an already-'approved' row with no way to tell "the
-- system just did this" from "a non-admin payer tried to self-approve" —
-- exactly the case this trigger's admin-only check exists to block. One
-- function sidesteps the ordering hazard entirely.
-- -----------------------------------------------------------------------------

create or replace function public.guard_expense_review_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _org_id        uuid;
  _threshold     numeric;
  _auto_approved boolean := false;
begin
  -- A submit or resubmit (transitioning into 'pending') may auto-resolve to
  -- 'approved' right here, before the admin-only check below ever applies,
  -- if the submitter's department (or the org's default) has a threshold
  -- and the amount is strictly under it. At-or-above the threshold still
  -- needs manual review.
  if new.approval_status = 'pending' and old.approval_status is distinct from 'pending' then
    select i.org_id into _org_id from public.itineraries i where i.id = new.itinerary_id;

    if _org_id is not null then
      select cfo.approval_threshold into _threshold
        from public.org_members om
        join public.org_cost_field_options cfo on cfo.id = om.cost_field_option_id
        where om.org_id = _org_id and om.user_id = new.payer_id;

      if _threshold is null then
        select default_approval_threshold into _threshold
          from public.organizations where id = _org_id;
      end if;

      if _threshold is not null and new.amount < _threshold then
        new.approval_status := 'approved';
        new.reviewed_at := now();
        _auto_approved := true;
      end if;
    end if;
  end if;

  -- auto_approved is fully server-computed, always, regardless of what a
  -- client sent — expenses_payer_update (stage29) lets a payer update any
  -- column on their own row, so without unconditionally overwriting this
  -- here, a payer could set auto_approved = true directly to slip past the
  -- admin-only check just below without actually qualifying for it.
  new.auto_approved := _auto_approved;

  if new.approval_status in ('approved', 'rejected')
     and new.approval_status is distinct from old.approval_status
     and not _auto_approved
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

-- -----------------------------------------------------------------------------
-- 2. Department-scoped feature-flag overrides — grant-only (never a deny):
--    a department can be given a premium feature (e.g. google_maps) even
--    when the org overall has no paid entitlement for it. Layered on top
--    of, never replacing, canUseFeatureProvider's existing per-user
--    isPremiumUserProvider check (lib/core/premium/premium_providers.dart)
--    — either one granting access is enough.
-- -----------------------------------------------------------------------------

create table if not exists public.org_feature_overrides (
  id                    uuid        primary key default gen_random_uuid(),
  cost_field_option_id  uuid        not null references public.org_cost_field_options(id) on delete cascade,
  feature_key           text        not null references public.feature_flags(feature_key) on delete cascade,
  enabled               boolean     not null default true,
  created_at            timestamptz not null default now(),
  unique (cost_field_option_id, feature_key)
);

-- Resolves the org via org_cost_field_options -> org_cost_fields, same
-- two-hop shape as is_org_member_for_cost_field/is_org_admin_for_cost_field
-- (stage31), which key off field_id rather than option_id directly.
create or replace function public.is_org_admin_for_cost_field_option(
  p_option_id uuid,
  p_user_id   uuid default auth.uid()
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.org_cost_field_options o
    where o.id = p_option_id
      and public.is_org_admin_for_cost_field(o.field_id, p_user_id)
  );
$$;

grant execute on function public.is_org_admin_for_cost_field_option(uuid, uuid) to authenticated;

alter table public.org_feature_overrides enable row level security;

drop policy if exists "org_feature_overrides_admin_all" on public.org_feature_overrides;
create policy "org_feature_overrides_admin_all" on public.org_feature_overrides
  for all
  using (public.is_org_admin_for_cost_field_option(cost_field_option_id))
  with check (public.is_org_admin_for_cost_field_option(cost_field_option_id));

-- No member-select policy: a regular member doesn't need to browse the
-- whole table, only to know whether *their own* department has an override
-- for a given feature — has_department_feature_override() below is that
-- narrow slice, the same "RPC instead of widening RLS" call already made
-- for set_org_default_approval_threshold above.

create or replace function public.has_department_feature_override(
  p_feature_key text
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.org_members om
    join public.org_feature_overrides ofo
      on ofo.cost_field_option_id = om.cost_field_option_id
    where om.user_id = auth.uid()
      and ofo.feature_key = p_feature_key
      and ofo.enabled = true
  );
$$;

grant execute on function public.has_department_feature_override(text) to authenticated;
