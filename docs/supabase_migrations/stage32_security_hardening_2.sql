-- =============================================================================
-- Stage 32 — Security hardening #2: fixes 3 findings from a security review
-- of stages 27-31 (work mode + trip email alias). Depends on stage27-31.
-- Safe to re-run: uses CREATE OR REPLACE / DROP ... IF EXISTS throughout.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- [SEC-1] generate_trip_email_alias(uuid) is SECURITY DEFINER and was granted
-- EXECUTE to `authenticated`, so it's callable directly as an RPC — not only
-- from the AFTER INSERT trigger it was written for. It never checked the
-- caller was actually the trip's owner/member before returning the row,
-- completely bypassing trip_email_aliases_member_select's RLS (SECURITY
-- DEFINER runs with the function owner's privileges, which ignores RLS on
-- tables the function itself queries). Net effect: any authenticated user
-- who ever learned an itinerary_id (a removed former member, a stale deep
-- link, a social-feed fork) could resolve that trip's masked forwarding
-- address forever, with membership removal never revoking it.
--
-- Fix: require the caller be the trip's owner or a member before returning
-- anything. The AFTER INSERT trigger still works unaffected — it always
-- fires with auth.uid() = the itinerary's owner_id, since only the owner
-- can INSERT an itinerary row (itineraries_owner_all's with check) and
-- "owner_id = auth.uid()" trivially satisfies the new check below.
-- -----------------------------------------------------------------------------

create or replace function public.generate_trip_email_alias(p_itinerary_id uuid)
returns public.trip_email_aliases
language plpgsql
security definer
set search_path = public
as $$
declare
  _alphabet   text := 'abcdefghjkmnpqrstuvwxyz23456789';
  _local_part text;
  _row        public.trip_email_aliases;
  _attempt    int := 0;
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
    raise exception 'Not authorized to access this trip''s email alias';
  end if;

  select * into _row from public.trip_email_aliases where itinerary_id = p_itinerary_id;
  if found then
    return _row;
  end if;

  loop
    _attempt := _attempt + 1;

    select 'trip-' || string_agg(
             substr(_alphabet, (random() * length(_alphabet))::int + 1, 1), ''
           )
      into _local_part
      from generate_series(1, 10);

    begin
      insert into public.trip_email_aliases (itinerary_id, local_part)
      values (p_itinerary_id, _local_part)
      returning * into _row;
      return _row;
    exception when unique_violation then
      if _attempt >= 5 then
        raise;
      end if;
    end;
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- [SEC-2] expenses_payer_update (stage29) validated only `payer_id =
-- auth.uid()` — no check that itinerary_id belongs to a trip the caller
-- actually has anything to do with, and no lock on financially-meaningful
-- fields once an expense is approved. Together this let a payer retarget
-- their own expense row's itinerary_id to ANY itinerary (via a direct
-- PostgREST call, not reachable through the Flutter app's own UI), which
-- set_expense_cost_center_code (stage30) would then snapshot that TARGET
-- org's real cost-center code onto, and expenses_org_admin_review_select's
-- is_org_admin_for_itinerary check (stage31) never verified the payer was
-- actually a member of that itinerary — so the forged row would surface in
-- a completely unrelated org's approval queue as a legitimate-looking
-- submission. Separately, nothing stopped editing amount/title/etc. on an
-- already-approved expense afterward.
--
-- Fix: two guard triggers. itinerary_id becomes fully immutable after
-- creation (no legitimate flow in this app ever moves an expense between
-- trips) — this alone closes the cross-tenant injection path outright.
-- Financially-meaningful fields are frozen for the payer once
-- approval_status = 'approved' (an org admin's own review path, gated by
-- is_org_admin_for_itinerary, is unaffected — they only ever touch
-- approval_status/reviewed_by/reviewed_at/rejection_reason).
-- -----------------------------------------------------------------------------

create or replace function public.guard_expense_itinerary_immutable()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.itinerary_id is distinct from old.itinerary_id then
    raise exception 'An expense cannot be moved to a different trip';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_expense_itinerary_immutable on public.expenses;
create trigger guard_expense_itinerary_immutable
  before update on public.expenses
  for each row execute function public.guard_expense_itinerary_immutable();

create or replace function public.guard_expense_locked_after_approval()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.approval_status = 'approved'
     and not public.is_org_admin_for_itinerary(old.itinerary_id)
     and (
       new.amount is distinct from old.amount
       or new.title is distinct from old.title
       or new.category is distinct from old.category
       or new.currency_code is distinct from old.currency_code
       or new.splits is distinct from old.splits
       or new.split_mode is distinct from old.split_mode
       or new.exchange_rate_to_base is distinct from old.exchange_rate_to_base
       or new.cost_center_code is distinct from old.cost_center_code
     )
  then
    raise exception 'This expense has already been approved and can no longer be edited';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_expense_locked_after_approval on public.expenses;
create trigger guard_expense_locked_after_approval
  before update on public.expenses
  for each row execute function public.guard_expense_locked_after_approval();

-- -----------------------------------------------------------------------------
-- [SEC-3] org_admin_trip_visibility_select (stage28) granted org admins
-- SELECT on the full `itineraries` row for any org-tagged trip — but
-- Postgres RLS is row-granular, not column-granular, so despite the
-- migration's own comment promising only "title, dates, status", it
-- actually exposed expense_summary (a jsonb aggregate over the trip's
-- ENTIRE expense history, personal spending included, not just
-- is_official/submitted items) and the full members roster (every
-- traveler's user id, name, and role — including people with zero
-- relationship to the org, e.g. a spouse or friend on the trip).
--
-- expenses_org_admin_review_select/update (stage29) do NOT actually depend
-- on this policy — they authorize via is_org_admin_for_itinerary(), a
-- SECURITY DEFINER function that bypasses itineraries' RLS internally. The
-- only real consumer was fetchPendingApprovals's PostgREST embed
-- (`itineraries!inner(title, org_id)`), which needed the trip title.
--
-- Fix: drop the blanket policy entirely (org admins get zero direct
-- table-level access to itineraries) and replace the embed with a narrow
-- SECURITY DEFINER RPC that does its own authorization check and returns
-- only the columns the approvals UI actually needs — see
-- fetch_org_pending_approvals below. Requires a matching Flutter change:
-- OrganizationRemoteDataSourceImpl.fetchPendingApprovals now calls this RPC
-- instead of embedding itineraries directly.
-- -----------------------------------------------------------------------------

drop policy if exists "org_admin_trip_visibility_select" on public.itineraries;

create or replace function public.fetch_org_pending_approvals(p_org_id uuid)
returns table (
  id            uuid,
  itinerary_id  uuid,
  trip_title    text,
  payer_id      uuid,
  payer_name    text,
  title         text,
  amount        numeric,
  currency_code text,
  category      text,
  submitted_at  timestamptz,
  notes         text,
  cost_center_code text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    e.id, e.itinerary_id, i.title as trip_title, e.payer_id, e.payer_name,
    e.title, e.amount, e.currency_code, e.category, e.submitted_at, e.notes,
    e.cost_center_code
  from public.expenses e
  join public.itineraries i on i.id = e.itinerary_id
  where i.org_id = p_org_id
    and public.is_org_admin(p_org_id)
    and e.is_official = true
    and e.approval_status = 'pending'
  order by e.submitted_at;
$$;

grant execute on function public.fetch_org_pending_approvals(uuid) to authenticated;
