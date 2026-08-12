-- =============================================================================
-- Stage 44 — Server-side 18+ age gate at signup.
--
-- Product decision (2026-08-12): Kumo account holders must be 18+. Kumo does
-- not create accounts, collect DOB-linked profiles, or store independent
-- data for anyone under 18 — full stop, not "verified but flagged." Minors
-- can still participate in trip planning, but only as non-account
-- "hitchhiker" collaborators attached to an adult's trip (see
-- stage45_hitchhikers.sql) — never as an independent data subject. See
-- docs/ARCHITECTURE.md's "Age gate & hitchhiker model" section for the
-- regulatory rationale (COPPA / UK AADC / GDPR).
--
-- This migration covers every path that inserts a row into auth.users:
--
--   1. Direct signup (email/password via supabase.auth.signUp()) — DOB is
--      supplied in the signup call's user metadata, so it's available at
--      INSERT time. A BEFORE INSERT trigger validates it and rejects the
--      INSERT outright (no account ever created) if under 18.
--
--   2. Invite-created accounts (supabase.auth.admin.inviteUserByEmail(),
--      called from supabase/functions/invite-email) — this row is created
--      by the INVITER, server-side, before the invitee has interacted with
--      anything, so there is no DOB to check yet at INSERT time. These rows
--      are allowed to be created (they have to be — that's how Supabase
--      invites work) but are left "unverified": profiles.age_verified_at
--      stays null, and the app (see lib/features/auth/presentation/
--      providers/age_gate_provider.dart + lib/config/router.dart) refuses
--      to grant access to anything beyond confirm_age_and_finish_signup()
--      below until the invitee supplies a DOB there. If they're under 18,
--      that RPC deletes the account immediately instead of activating it —
--      the same end state as path 1 (no account), just reached one step
--      later because the platform's invite mechanics require the row to
--      exist first. This asymmetry is unavoidable, not a design choice.
--
-- Data minimisation: raw DOB is never persisted. The BEFORE INSERT trigger
-- computes the age check and immediately strips date_of_birth out of
-- raw_user_meta_data before the row is written — only a boolean pass/fail
-- (raw_app_meta_data->>'age_verified', server-controlled, not user-editable)
-- survives in auth.users, and only a timestamp (profiles.age_verified_at —
-- "this identity cleared the gate on this date") survives in public.profiles.
-- There is no other legitimate product use for DOB in Kumo today (no
-- birthday reminders, no age-restricted content beyond this gate itself),
-- so nothing beyond the pass/fail fact is kept.
--
-- Safe to re-run: uses CREATE OR REPLACE / DROP TRIGGER IF EXISTS throughout.
-- Run in Supabase SQL editor before deploying the corresponding app build.
-- =============================================================================

-- ── 1. profiles.age_verified_at ──────────────────────────────────────────────

alter table public.profiles
  add column if not exists age_verified_at timestamptz;

comment on column public.profiles.age_verified_at is
  'Timestamp this identity was confirmed 18+. Null = not yet verified — the '
  'app must force /confirm-age before granting any real access. Never '
  'derived from a stored date of birth; only the pass/fail fact is kept.';

-- Solo-dev, pre-launch project (see CLAUDE.md) — no real minor users exist
-- in the current data. Grandfather every pre-existing account rather than
-- forcing every already-trusted test/dev account through the gate on next
-- open. A production launch with a real user base would need a real
-- decision here instead of a blanket backfill.
update public.profiles set age_verified_at = created_at
where age_verified_at is null;

-- ── 2. BEFORE INSERT gate on auth.users ──────────────────────────────────────
-- BEFORE (not AFTER) so a failing check can reject the row before it's ever
-- written, and so a passing check can scrub raw_user_meta_data in place
-- (AFTER triggers can't modify what gets persisted — only BEFORE can).

create or replace function public.enforce_signup_age_gate()
returns trigger
language plpgsql
as $$
declare
  _dob date;
  _age int;
begin
  _dob := nullif(new.raw_user_meta_data->>'date_of_birth', '')::date;

  if _dob is not null then
    if _dob > current_date then
      raise exception 'Date of birth cannot be in the future.';
    end if;

    _age := extract(year from age(_dob));
    if _age < 18 then
      raise exception 'Kumo accounts require you to be 18 or older.'
        using errcode = 'check_violation';
    end if;

    -- Passed — record the pass/fail fact in server-controlled app metadata
    -- (handle_new_user reads this to stamp profiles.age_verified_at below),
    -- then strip the raw date out of user metadata before it's ever written.
    new.raw_app_meta_data :=
      coalesce(new.raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('age_verified', true);
    new.raw_user_meta_data := new.raw_user_meta_data - 'date_of_birth';
  end if;

  -- _dob is null: no date of birth was supplied at INSERT time — either an
  -- invite/admin-created row (see this file's header comment) or a
  -- malformed/omitted signup payload. Either way this is NOT a bypass: the
  -- row is allowed to be created, but handle_new_user leaves
  -- profiles.age_verified_at null, and the app refuses real access until
  -- confirm_age_and_finish_signup() below is called successfully.
  return new;
end;
$$;

drop trigger if exists on_auth_user_age_gate on auth.users;
create trigger on_auth_user_age_gate
  before insert on auth.users
  for each row execute function public.enforce_signup_age_gate();

-- ── 3. Reissue handle_new_user() to stamp age_verified_at ────────────────────
-- Also restores the pending_invitations auto-join loop that stage2b added
-- and stage21_trip_segments.sql's redefinition (premium trial) silently
-- dropped — found while tracing the current definition for this migration.
-- Since stage21, a user who signs up after being invited to a trip by email
-- never got auto-added to that trip; their pending_invitations row just sat
-- there unconsumed. Not part of the age-gate work, but this is the function
-- that regressed it and the one being reissued anyway.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _trial_days int;
  inv record;
  new_member jsonb;
begin
  select coalesce(value::int, 14) into _trial_days
  from public.app_config where key = 'trial_duration_days';
  _trial_days := coalesce(_trial_days, 14);

  insert into public.profiles (id, display_name, email, age_verified_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', ''),
    new.email,
    case
      when (new.raw_app_meta_data->>'age_verified')::boolean is true then now()
      else null
    end
  )
  on conflict (id) do nothing;

  insert into public.profile_status (user_id, status, reason, expires_at)
  values (
    new.id,
    'premium',
    _trial_days || '-day trial on signup',
    now() + make_interval(days => _trial_days)
  )
  on conflict do nothing;

  perform public.seed_notification_preferences(new.id);

  -- Auto-join any pending invitations for this email (restored — see header).
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

-- ── 4. confirm_age_and_finish_signup() — invite-path completion gate ────────
-- Called once, right after an invited user's first successful login (see
-- lib/features/auth/presentation/providers/age_gate_provider.dart), while
-- profiles.age_verified_at is still null for them.
--
-- Returns text rather than raising on the "underage" outcome deliberately:
-- raising an exception aborts the whole transaction, which would undo the
-- delete below and leave the account intact — the opposite of what's
-- needed. A normal return lets the delete commit and reports the outcome to
-- the caller as data instead.
create or replace function public.confirm_age_and_finish_signup(p_date_of_birth date)
returns text -- 'verified' | 'rejected_underage'
language plpgsql
security definer
set search_path = public
as $$
declare
  _uid uuid := auth.uid();
  _age int;
begin
  if _uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_date_of_birth is null then
    raise exception 'Date of birth is required';
  end if;
  if p_date_of_birth > current_date then
    raise exception 'Date of birth cannot be in the future.';
  end if;

  _age := extract(year from age(p_date_of_birth));
  if _age < 18 then
    -- Reject — no Kumo account for a minor, full stop. delete_user()'s own
    -- cascades (see stage14_delete_user_rpc.sql / stage23's FK fixes) clean
    -- up everything; this just calls the same underlying deletion path
    -- (via auth.users, not the public delete_user() wrapper, since that
    -- wrapper is written for a self-service "delete my own account" click,
    -- not this reject-at-verification path — the cascades it relies on are
    -- identical either way).
    delete from auth.users where id = _uid;
    return 'rejected_underage';
  end if;

  update public.profiles set age_verified_at = now() where id = _uid;
  return 'verified';
end;
$$;

revoke all on function public.confirm_age_and_finish_signup(date) from anon;
grant execute on function public.confirm_age_and_finish_signup(date) to authenticated;
