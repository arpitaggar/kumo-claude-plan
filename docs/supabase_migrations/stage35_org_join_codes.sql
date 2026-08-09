-- =============================================================================
-- Stage 35 — Org join codes: self-serve onboarding into Work Mode via a
-- scannable/typeable code, optionally scoped to a department (an existing
-- org_cost_field_options row — e.g. "Sales", "Engineering"). An admin
-- generates a code (shown as text + QR in the app); anyone who redeems it
-- while signed into their own Kumo account is added to that org under that
-- department. Safe to re-run: uses IF NOT EXISTS / CREATE OR REPLACE /
-- DROP IF EXISTS throughout.
--
-- This area of the schema already had one security-hardening pass (stage31:
-- an RLS self-recursion; stage32: an unauthenticated "generate a code" RPC
-- IDOR, a cross-tenant injection path, an over-broad admin SELECT policy).
-- Every RPC below explicitly re-checks caller authorization inside its own
-- body (SECURITY DEFINER bypasses RLS — the in-body check IS the
-- authorization, not a redundant belt-and-braces addition) and every
-- mutable table has no direct authenticated write policy at all — only the
-- RPCs can write, so a bug in one RPC's own logic can't be routed around
-- via a raw PostgREST call the way generate_trip_email_alias's IDOR could.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. org_join_codes
-- -----------------------------------------------------------------------------

create table if not exists public.org_join_codes (
  id                    uuid        primary key default gen_random_uuid(),
  org_id                uuid        not null references public.organizations(id) on delete cascade,
  -- Which department this code grants, if any — an org that hasn't set up
  -- cost fields yet can still generate a plain, unscoped code.
  -- ON DELETE RESTRICT (not SET NULL): an in-use code shouldn't silently
  -- lose its department scoping out from under it if an admin deletes the
  -- option elsewhere — see deleteCostFieldOption's generalized error below.
  cost_field_option_id  uuid        references public.org_cost_field_options(id) on delete restrict,
  -- Never 'owner' — mirrors org_members_manage_insert's own constraint
  -- (stage31). A join code is a self-serve path; it must never be able to
  -- mint an org owner.
  role                  text        not null default 'member'
                                    check (role in ('admin', 'member')),
  -- Globally unique, not unique-per-org: redeem_org_join_code takes only
  -- the code, never an org id from the client, and resolves org_id
  -- entirely server-side — a client can never claim "redeem code X into
  -- org Y".
  code                  text        not null unique,
  expires_at            timestamptz,
  max_uses              int         check (max_uses is null or max_uses > 0),
  uses_count            int         not null default 0 check (uses_count >= 0),
  revoked_at            timestamptz,
  created_by            uuid        not null references auth.users(id) on delete cascade,
  created_at            timestamptz not null default now(),
  -- Defense-in-depth: even if redeem_org_join_code's own FOR UPDATE
  -- concurrency guard (see the function below) had a bug, the database
  -- itself refuses to let uses_count exceed max_uses.
  check (max_uses is null or uses_count <= max_uses)
);

create index if not exists org_join_codes_org_id_idx on public.org_join_codes (org_id);

alter table public.org_join_codes enable row level security;

drop policy if exists "org_join_codes_admin_select" on public.org_join_codes;

-- Admins can list/manage their org's codes. Every column here is something
-- the admin list screen legitimately needs to display (code, status,
-- department, usage) — unlike itineraries' SEC-3 bug (stage32), there's no
-- unrelated sensitive data riding along on this row, so a direct SELECT
-- policy is correct here, not a shortcut that needs a narrower RPC instead.
create policy "org_join_codes_admin_select" on public.org_join_codes
  for select using (public.is_org_admin(org_id));

-- Deliberately NO insert/update/delete policy for `authenticated` at all —
-- every mutation goes exclusively through generate_org_join_code /
-- redeem_org_join_code / revoke_org_join_code below. Even a bug in one of
-- those functions' own auth check can't be routed around via a raw
-- `.from('org_join_codes').insert(...)` PostgREST call, because no policy
-- would ever authorize it. Same "no write policy, only the generator
-- function writes" precedent as trip_email_aliases (stage27).

-- -----------------------------------------------------------------------------
-- 2. org_members gains a department hook
--
-- Denormalised from the join code redeemed (or settable by an admin
-- directly later) so "who's in which department" is answerable at all.
-- NOT used for any gating/routing logic today — per-department feature
-- flags and approval routing are explicitly deferred future work; this
-- column exists now purely so that future work has data to key off without
-- a backfill.
-- -----------------------------------------------------------------------------

alter table public.org_members
  add column if not exists cost_field_option_id uuid references public.org_cost_field_options(id) on delete set null;

comment on column public.org_members.cost_field_option_id is
  'The org_cost_field_option (e.g. a Department value) this member joined '
  'under, denormalized from the join code they redeemed. Not currently '
  'used for any gating/routing logic — see stage35''s migration header.';

-- ON DELETE SET NULL here, asymmetric with org_join_codes' ON DELETE
-- RESTRICT above, on purpose: a membership record shouldn't block an admin
-- from deleting an old department option years later just because someone
-- historically joined under it — unlike an active join code, there's
-- nothing currently being granted by this reference once the person is
-- already a member.

-- Cross-org integrity RLS can't express (a plain UPDATE policy checks only
-- role, not this new column) — without this, an org-A admin could PATCH an
-- org-A member's cost_field_option_id to an org-B option via a direct
-- PostgREST call. Harmless for access control, but silent data corruption;
-- same idiom as guard_org_cost_field_source (stage30).
create or replace function public.guard_org_member_cost_field_option()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _field_org_id uuid;
begin
  if new.cost_field_option_id is null then
    return new;
  end if;

  select f.org_id into _field_org_id
  from public.org_cost_field_options o
  join public.org_cost_fields f on f.id = o.field_id
  where o.id = new.cost_field_option_id;

  if _field_org_id is distinct from new.org_id then
    raise exception 'This department option does not belong to this member''s organization';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_org_member_cost_field_option on public.org_members;
create trigger guard_org_member_cost_field_option
  before insert or update on public.org_members
  for each row execute function public.guard_org_member_cost_field_option();

-- -----------------------------------------------------------------------------
-- 3. generate_org_join_code — admin-only
-- -----------------------------------------------------------------------------

create or replace function public.generate_org_join_code(
  p_org_id               uuid,
  p_cost_field_option_id uuid default null,
  p_role                 text default 'member',
  p_expires_at           timestamptz default null,
  p_max_uses             int default null
) returns public.org_join_codes
language plpgsql
security definer
set search_path = public
as $$
declare
  -- 32-symbol alphabet excluding 0/1/I/O/L look-alikes. 10 characters ->
  -- ~2^50 combinations. A join code is a real trust boundary (grants org
  -- membership), not just a collision-avoidance concern like
  -- trip_email_aliases' shorter local part (stage27) — sized accordingly.
  _alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  _code     text;
  _row      public.org_join_codes;
  _attempt  int := 0;
begin
  -- Explicit authorization check — SECURITY DEFINER bypasses org_members'
  -- own RLS, so this check IS the authorization (the stage32 SEC-1 lesson:
  -- generate_trip_email_alias originally had no equivalent check).
  if not public.is_org_admin(p_org_id) then
    raise exception 'Not authorized to generate a join code for this organization';
  end if;

  if p_role not in ('admin', 'member') then
    raise exception 'Invalid role for a join code';
  end if;

  if p_max_uses is not null and p_max_uses < 1 then
    raise exception 'max_uses must be at least 1';
  end if;

  -- Cross-org reference guard — an org-A admin must not be able to scope a
  -- code to org B's department option, even though it wouldn't grant
  -- access to org B on its own (same idiom as guard_org_cost_field_source,
  -- stage30).
  if p_cost_field_option_id is not null and not exists (
    select 1 from public.org_cost_field_options o
    join public.org_cost_fields f on f.id = o.field_id
    where o.id = p_cost_field_option_id and f.org_id = p_org_id
  ) then
    raise exception 'This department option does not belong to this organization';
  end if;

  loop
    _attempt := _attempt + 1;
    select string_agg(
      substr(_alphabet, (random() * length(_alphabet))::int + 1, 1), ''
    ) into _code
    from generate_series(1, 10);

    begin
      insert into public.org_join_codes (
        org_id, cost_field_option_id, role, code, expires_at, max_uses, created_by
      ) values (
        p_org_id, p_cost_field_option_id, p_role, _code, p_expires_at, p_max_uses, auth.uid()
      ) returning * into _row;
      return _row;
    exception when unique_violation then
      if _attempt >= 5 then
        raise exception 'Could not generate a unique join code, please try again';
      end if;
    end;
  end loop;
end;
$$;

grant execute on function public.generate_org_join_code(uuid, uuid, text, timestamptz, int) to authenticated;
revoke execute on function public.generate_org_join_code(uuid, uuid, text, timestamptz, int) from public;

-- -----------------------------------------------------------------------------
-- 4. revoke_org_join_code — admin-only
-- -----------------------------------------------------------------------------

create or replace function public.revoke_org_join_code(p_code_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  _org_id uuid;
begin
  select org_id into _org_id from public.org_join_codes where id = p_code_id;
  if _org_id is null then
    raise exception 'Join code not found';
  end if;
  if not public.is_org_admin(_org_id) then
    raise exception 'Not authorized to revoke this join code';
  end if;

  update public.org_join_codes
  set revoked_at = now()
  where id = p_code_id and revoked_at is null;
end;
$$;

grant execute on function public.revoke_org_join_code(uuid) to authenticated;
revoke execute on function public.revoke_org_join_code(uuid) from public;

-- -----------------------------------------------------------------------------
-- 5. redeem_org_join_code — any authenticated user, not just existing
--    org members. This is the one RPC in this migration that a non-member
--    is expected to call.
-- -----------------------------------------------------------------------------

create or replace function public.redeem_org_join_code(p_code text)
returns public.organizations
language plpgsql
security definer
set search_path = public
as $$
declare
  _code_row     public.org_join_codes;
  _org          public.organizations;
  _uid          uuid := auth.uid();
  _display_name text;
begin
  if _uid is null then
    raise exception 'Not authenticated';
  end if;

  select display_name into _display_name from public.profiles where id = _uid;

  -- Abuse guard on SUCCESSFUL joins, not attempts. A failed-attempt counter
  -- doesn't work here: RAISE EXCEPTION aborts the whole transaction,
  -- undoing any "log this attempt" row along with it, so failed guesses
  -- would never actually accumulate without an autonomous-transaction
  -- mechanism (dblink/pg_net/an Edge Function in front) this codebase
  -- doesn't use elsewhere. Counting committed rows instead — same idiom as
  -- guard_publish_rate_limit (stage34) — sidesteps that problem entirely.
  -- The primary defense against guessing is the code's own entropy (~2^50
  -- combinations, see generate_org_join_code above), not this counter.
  if (
    select count(*) from public.org_members
    where user_id = _uid and joined_at > now() - interval '1 hour'
  ) >= 10 then
    raise exception 'Too many organizations joined recently. Please try again later.';
  end if;

  -- Row lock: acquires (or blocks on) an exclusive lock on this specific
  -- code's row. If two transactions redeem the same code concurrently, the
  -- second blocks until the first commits or rolls back, then re-reads the
  -- post-commit row (normal Postgres lock semantics) — so its own
  -- uses_count/max_uses check below correctly sees the fresh value. Plain
  -- SELECTs (the admin list page) are never blocked by this — FOR UPDATE
  -- only serializes against other row-locking writers.
  select * into _code_row
  from public.org_join_codes
  where code = trim(p_code)
  for update;

  if not found then
    raise exception 'Invalid join code';
  end if;
  if _code_row.revoked_at is not null then
    raise exception 'This join code has been revoked';
  end if;
  if _code_row.expires_at is not null and _code_row.expires_at <= now() then
    raise exception 'This join code has expired';
  end if;
  if _code_row.max_uses is not null and _code_row.uses_count >= _code_row.max_uses then
    raise exception 'This join code has reached its use limit';
  end if;
  if exists (
    select 1 from public.org_members
    where org_id = _code_row.org_id and user_id = _uid
  ) then
    raise exception 'You are already a member of this organization';
  end if;

  update public.org_join_codes
  set uses_count = uses_count + 1
  where id = _code_row.id;

  begin
    insert into public.org_members (org_id, user_id, user_name, role, cost_field_option_id)
    values (
      _code_row.org_id, _uid, coalesce(_display_name, ''), _code_row.role,
      _code_row.cost_field_option_id
    );
  exception when unique_violation then
    -- Catches the one race FOR UPDATE above doesn't cover: the same user
    -- redeeming two DIFFERENT codes for the same org at the same moment
    -- (e.g. a double-tap firing two RPC calls). Different code rows mean
    -- that lock doesn't serialize these two calls against each other —
    -- org_members' own unique(org_id, user_id) constraint is the real
    -- backstop. Raising here rolls back the WHOLE transaction, including
    -- the uses_count increment just above, so a failed join never spends
    -- the code.
    raise exception 'You are already a member of this organization';
  end;

  select * into _org from public.organizations where id = _code_row.org_id;
  return _org;
end;
$$;

grant execute on function public.redeem_org_join_code(text) to authenticated;
revoke execute on function public.redeem_org_join_code(text) from public;
