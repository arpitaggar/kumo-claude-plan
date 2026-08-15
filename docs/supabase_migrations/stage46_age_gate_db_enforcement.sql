-- =============================================================================
-- Stage 46 — DB-level enforcement of the age gate for invite-created accounts
-- (SEC-033, docs/SECURITY_AUDIT.md).
--
-- stage44_age_gate.sql's BEFORE INSERT trigger on auth.users only covers
-- *account creation*. For an invite-created account, profiles.age_verified_at
-- stays null until confirm_age_and_finish_signup() runs successfully — and
-- until this migration, nothing in Postgres actually required that to happen
-- before the account could write anywhere else. Enforcement lived entirely
-- in the Flutter router's redirect to /confirm-age
-- (lib/features/auth/presentation/providers/age_gate_provider.dart), which a
-- technically capable invitee could simply skip by calling Supabase's
-- REST/RPC endpoints directly with their own session token.
--
-- This migration closes that gap with a single reusable BEFORE INSERT OR
-- UPDATE trigger, attached explicitly (not via a dynamic loop — this
-- codebase's migrations are written table-by-table throughout, and a
-- literal per-table CREATE TRIGGER is what
-- scripts/check_age_gate_coverage.sh's pre-commit lint scans for) to every
-- table where writing means acting as a full, independent data subject per
-- the regulatory rationale in docs/ARCHITECTURE.md's "Age gate & hitchhiker
-- model" section:
--
--   itineraries, messages, itinerary_posts, post_likes, follows,
--   post_comments, expenses, ratings, packing_items, trip_segments
--
-- (Trip "notes" is a text column on itineraries, not a separate table, so
-- it's already covered by that one.)
--
-- Deliberately NOT gated:
--   - DELETE on any table — removing your own data isn't the regulated
--     activity; only creating/editing it is.
--   - public.profiles itself — this is the table that *records*
--     verification. Gating writes to it would make it impossible for an
--     unverified user to ever call confirm_age_and_finish_signup() and set
--     age_verified_at in the first place.
--   - Hitchhiker-authored writes (public.itinerary_suggestions, and
--     hitchhiker_send_message's insert into public.messages) — Hitchhikers
--     are non-account collaborators authenticated via token RPCs, not
--     auth.uid()-bearing sessions (see stage45_hitchhikers.sql and
--     lib/features/hitchhiker/CLAUDE.md). The whole point of that design is
--     that a Hitchhiker is never an independent data subject in the first
--     place, so this gate structurally doesn't apply — require_age_verified()
--     below no-ops whenever auth.uid() is null, which covers both this case
--     and plain service-role/migration-context writes.
--
-- Retroactivity: stage44_age_gate.sql already grandfathered every
-- pre-existing account by backfilling age_verified_at = created_at for
-- anyone still null at that migration's run, and handle_new_user() stamps
-- direct signups verified at profile-creation time. So in practice this
-- guard only ever blocks the narrow window SEC-033 is actually about — an
-- invite-created account that hasn't yet called
-- confirm_age_and_finish_signup() — not any existing, already-active user.
--
-- Future tables: scripts/check_age_gate_coverage.sh (run by
-- scripts/hooks/pre-commit) fails a commit that adds a new public table
-- with neither a require_age_verified() trigger nor an explicit
-- `-- age-gate-exempt: public.<table> — <reason>` comment in the same
-- migration file. See that script for exactly what it checks.
--
-- Safe to re-run: uses CREATE OR REPLACE / DROP TRIGGER IF EXISTS throughout.
-- Run in Supabase SQL editor before deploying the corresponding app build.
-- =============================================================================

-- ── 1. The reusable guard function ───────────────────────────────────────────

create or replace function public.require_age_verified()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- No auth.uid() at all means this write isn't coming from an
  -- authenticated end-user session (service-role script, a migration, or
  -- an internal trigger like handle_new_user()'s pending-invitation
  -- auto-join UPDATE on itineraries, which runs from GoTrue's own
  -- connection with no request JWT in scope) — nothing here to gate.
  if auth.uid() is null then
    return new;
  end if;

  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and age_verified_at is not null
  ) then
    raise exception
      'Age verification required before this action. Please finish signup first.'
      using errcode = '42501'; -- insufficient_privilege
  end if;

  return new;
end;
$$;

comment on function public.require_age_verified() is
  'SEC-033 remediation — blocks INSERT/UPDATE from an authenticated but not '
  'yet age-verified session (invite-path accounts pending '
  'confirm_age_and_finish_signup()). See this migration''s header comment '
  'for the guarded table list and what''s deliberately excluded.';

-- ── 2. Attach to every guarded table ─────────────────────────────────────────

drop trigger if exists trg_require_age_verified on public.itineraries;
create trigger trg_require_age_verified
  before insert or update on public.itineraries
  for each row execute function public.require_age_verified();

drop trigger if exists trg_require_age_verified on public.messages;
create trigger trg_require_age_verified
  before insert or update on public.messages
  for each row execute function public.require_age_verified();

drop trigger if exists trg_require_age_verified on public.itinerary_posts;
create trigger trg_require_age_verified
  before insert or update on public.itinerary_posts
  for each row execute function public.require_age_verified();

drop trigger if exists trg_require_age_verified on public.post_likes;
create trigger trg_require_age_verified
  before insert or update on public.post_likes
  for each row execute function public.require_age_verified();

drop trigger if exists trg_require_age_verified on public.follows;
create trigger trg_require_age_verified
  before insert or update on public.follows
  for each row execute function public.require_age_verified();

drop trigger if exists trg_require_age_verified on public.post_comments;
create trigger trg_require_age_verified
  before insert or update on public.post_comments
  for each row execute function public.require_age_verified();

drop trigger if exists trg_require_age_verified on public.expenses;
create trigger trg_require_age_verified
  before insert or update on public.expenses
  for each row execute function public.require_age_verified();

drop trigger if exists trg_require_age_verified on public.ratings;
create trigger trg_require_age_verified
  before insert or update on public.ratings
  for each row execute function public.require_age_verified();

drop trigger if exists trg_require_age_verified on public.packing_items;
create trigger trg_require_age_verified
  before insert or update on public.packing_items
  for each row execute function public.require_age_verified();

drop trigger if exists trg_require_age_verified on public.trip_segments;
create trigger trg_require_age_verified
  before insert or update on public.trip_segments
  for each row execute function public.require_age_verified();
