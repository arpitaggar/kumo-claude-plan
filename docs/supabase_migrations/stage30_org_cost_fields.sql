-- =============================================================================
-- Stage 30 — Org-defined cost-tracking structure (custom fields, generated
-- cost-center codes, per-trip assignment, snapshot onto submitted expenses)
-- Depends on stage28 (organizations/org_members) and stage29 (expenses'
-- is_official/approval_status columns). Safe to re-run.
-- =============================================================================
--
-- Each org defines its own arbitrary set of `select`-type fields (org admin
-- manages a free-text value+code list per field — e.g. Department:
-- "Sales"->"SAL") and at most one `generated`-type field whose value is the
-- concatenation of chosen source fields' option codes (e.g. "SAL-FAL"). One
-- structure per org — no sub-units; a company needing a different structure
-- per country creates a separate Kumo organization (same instinct as
-- stage28's deliberately narrow role vocabulary).
--
-- Resolution happens through ONE shared SQL function so the logic never
-- drifts between its two call sites: (1) a live-preview RPC callable while a
-- trip is still being created/edited, before anything is persisted; (2) a
-- BEFORE UPDATE trigger on expenses that snapshots the resolved code onto
-- expenses.cost_center_code the moment approval_status moves to 'pending'
-- (submit or resubmit) — deliberately a snapshot, not a live join: if a
-- trip's cost-center assignment is corrected later, an already-submitted or
-- already-approved expense must not silently change which account it posts
-- to. This requires zero changes to stage29's submitForApproval, whose
-- single-payload batched update this trigger fires against per-row,
-- resolving off itinerary_id (already on every row) rather than anything in
-- the payload itself.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. org_cost_fields — one row per org-defined field. No separate machine
--    `key` column: every reference elsewhere in this schema addresses a
--    field by its uuid, so a second stable identifier would be speculative
--    surface area with nothing that needs it yet.
-- -----------------------------------------------------------------------------

create table if not exists public.org_cost_fields (
  id         uuid        primary key default gen_random_uuid(),
  org_id     uuid        not null references public.organizations(id) on delete cascade,
  label      text        not null,
  field_type text        not null check (field_type in ('select', 'generated')),
  separator  text        not null default '-',   -- meaningful only for 'generated'
  sort_order int         not null default 0,
  created_at timestamptz not null default now(),
  unique (org_id, label)
);

-- At most one generated field per org — enforced here, not just documented.
-- A real multi-code use case would need a resolution-function signature
-- change (which field to resolve); deferred until an org actually asks.
create unique index if not exists org_cost_fields_one_generated_per_org
  on public.org_cost_fields (org_id) where field_type = 'generated';

-- -----------------------------------------------------------------------------
-- 2. org_cost_field_options — the admin-managed value+code list for a
--    'select' field. `on delete restrict` (the implicit default for a
--    plain FK, spelled out below via explicit ON DELETE clauses elsewhere in
--    this file) is deliberately the entire mechanism for "block delete of an
--    option already in use by an existing trip" — no bespoke guard trigger
--    needed for that part.
-- -----------------------------------------------------------------------------

create table if not exists public.org_cost_field_options (
  id         uuid        primary key default gen_random_uuid(),
  field_id   uuid        not null references public.org_cost_fields(id) on delete cascade,
  value      text        not null,
  code       text        not null,
  sort_order int         not null default 0,
  created_at timestamptz not null default now(),
  unique (field_id, value),
  unique (field_id, code)
);

-- -----------------------------------------------------------------------------
-- 3. org_cost_field_sources — ordered list of which select-type fields feed
--    a generated field's concatenation. A join table (not a plain uuid[]
--    column) so "can't delete a field still used as a source" is a plain FK
--    restrict, not more trigger machinery.
-- -----------------------------------------------------------------------------

create table if not exists public.org_cost_field_sources (
  generated_field_id uuid not null references public.org_cost_fields(id) on delete cascade,
  source_field_id     uuid not null references public.org_cost_fields(id) on delete restrict,
  position             int  not null,
  primary key (generated_field_id, source_field_id),
  unique (generated_field_id, position)
);

-- -----------------------------------------------------------------------------
-- 4. trip_cost_field_values — one selected option per select-type field per
--    trip. field_id/option_id both `on delete restrict`: can't delete a
--    field or option definition an existing trip has actually used.
-- -----------------------------------------------------------------------------

create table if not exists public.trip_cost_field_values (
  id           uuid        primary key default gen_random_uuid(),
  itinerary_id uuid        not null references public.itineraries(id) on delete cascade,
  field_id     uuid        not null references public.org_cost_fields(id) on delete restrict,
  option_id    uuid        not null references public.org_cost_field_options(id) on delete restrict,
  set_at       timestamptz not null default now(),
  unique (itinerary_id, field_id)
);

create index if not exists trip_cost_field_values_itinerary_id_idx
  on public.trip_cost_field_values (itinerary_id);

-- -----------------------------------------------------------------------------
-- 5. RLS — org_cost_fields / org_cost_field_options / org_cost_field_sources.
--    Read: any org member (travelers need to see options to tag their own
--    trip). Write: owner/admin only — same role check org_members already
--    uses.
-- -----------------------------------------------------------------------------

alter table public.org_cost_fields enable row level security;
alter table public.org_cost_field_options enable row level security;
alter table public.org_cost_field_sources enable row level security;

drop policy if exists "org_cost_fields_member_select" on public.org_cost_fields;
drop policy if exists "org_cost_fields_admin_write" on public.org_cost_fields;

create policy "org_cost_fields_member_select" on public.org_cost_fields
  for select using (
    exists (select 1 from public.org_members om
            where om.org_id = org_cost_fields.org_id and om.user_id = auth.uid())
  );

create policy "org_cost_fields_admin_write" on public.org_cost_fields
  for all
  using (
    exists (select 1 from public.org_members om
            where om.org_id = org_cost_fields.org_id and om.user_id = auth.uid()
              and om.role in ('owner', 'admin'))
  )
  with check (
    exists (select 1 from public.org_members om
            where om.org_id = org_cost_fields.org_id and om.user_id = auth.uid()
              and om.role in ('owner', 'admin'))
  );

drop policy if exists "org_cost_field_options_member_select" on public.org_cost_field_options;
drop policy if exists "org_cost_field_options_admin_write" on public.org_cost_field_options;

create policy "org_cost_field_options_member_select" on public.org_cost_field_options
  for select using (
    exists (select 1 from public.org_cost_fields f
            join public.org_members om on om.org_id = f.org_id
            where f.id = org_cost_field_options.field_id and om.user_id = auth.uid())
  );

create policy "org_cost_field_options_admin_write" on public.org_cost_field_options
  for all
  using (
    exists (select 1 from public.org_cost_fields f
            join public.org_members om on om.org_id = f.org_id
            where f.id = org_cost_field_options.field_id and om.user_id = auth.uid()
              and om.role in ('owner', 'admin'))
  )
  with check (
    exists (select 1 from public.org_cost_fields f
            join public.org_members om on om.org_id = f.org_id
            where f.id = org_cost_field_options.field_id and om.user_id = auth.uid()
              and om.role in ('owner', 'admin'))
  );

drop policy if exists "org_cost_field_sources_member_select" on public.org_cost_field_sources;
drop policy if exists "org_cost_field_sources_admin_write" on public.org_cost_field_sources;

create policy "org_cost_field_sources_member_select" on public.org_cost_field_sources
  for select using (
    exists (select 1 from public.org_cost_fields f
            join public.org_members om on om.org_id = f.org_id
            where f.id = org_cost_field_sources.generated_field_id and om.user_id = auth.uid())
  );

create policy "org_cost_field_sources_admin_write" on public.org_cost_field_sources
  for all
  using (
    exists (select 1 from public.org_cost_fields f
            join public.org_members om on om.org_id = f.org_id
            where f.id = org_cost_field_sources.generated_field_id and om.user_id = auth.uid()
              and om.role in ('owner', 'admin'))
  )
  with check (
    exists (select 1 from public.org_cost_fields f
            join public.org_members om on om.org_id = f.org_id
            where f.id = org_cost_field_sources.generated_field_id and om.user_id = auth.uid()
              and om.role in ('owner', 'admin'))
  );

-- -----------------------------------------------------------------------------
-- 6. Column/cross-table guards RLS can't express — same idiom as stage28's
--    guard_org_id_change / stage29's guard_expense_review_fields.
-- -----------------------------------------------------------------------------

-- A generated field can only draw from THIS SAME org's select-type fields —
-- blocks both cross-org references and nested generated->generated chaining
-- (multi-level generated fields are deferred).
create or replace function public.guard_org_cost_field_source()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _gen_org  uuid;
  _gen_type text;
  _src_org  uuid;
  _src_type text;
begin
  select org_id, field_type into _gen_org, _gen_type
  from public.org_cost_fields where id = new.generated_field_id;
  if _gen_type is distinct from 'generated' then
    raise exception 'Sources can only be attached to a generated-type field';
  end if;

  select org_id, field_type into _src_org, _src_type
  from public.org_cost_fields where id = new.source_field_id;
  if _src_org is distinct from _gen_org then
    raise exception 'Source field belongs to a different organization';
  end if;
  if _src_type <> 'select' then
    raise exception 'A generated field can only draw from select-type fields';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_org_cost_field_source on public.org_cost_field_sources;
create trigger guard_org_cost_field_source
  before insert or update on public.org_cost_field_sources
  for each row execute function public.guard_org_cost_field_source();

-- Options can only be attached to a select-type field (generated fields are
-- computed, never admin-entered).
create or replace function public.guard_org_cost_field_option()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _t text;
begin
  select field_type into _t from public.org_cost_fields where id = new.field_id;
  if _t <> 'select' then
    raise exception 'Options can only be added to a select-type field';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_org_cost_field_option on public.org_cost_field_options;
create trigger guard_org_cost_field_option
  before insert or update on public.org_cost_field_options
  for each row execute function public.guard_org_cost_field_option();

-- A trip's assignment can only reference a field/option that (a) belongs to
-- the trip's OWN org, and (b) is a select-type field (values aren't set
-- directly on a generated field — they're computed).
create or replace function public.guard_trip_cost_field_value()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _org_id          uuid;
  _field_org_id    uuid;
  _field_type      text;
  _option_field_id uuid;
begin
  select org_id into _org_id from public.itineraries where id = new.itinerary_id;
  if _org_id is null then
    raise exception 'Trip must belong to an organization to set cost-tracking fields';
  end if;

  select org_id, field_type into _field_org_id, _field_type
  from public.org_cost_fields where id = new.field_id;
  if _field_org_id is distinct from _org_id then
    raise exception 'This field does not belong to the trip''s organization';
  end if;
  if _field_type <> 'select' then
    raise exception 'Only select-type fields can be assigned a value directly';
  end if;

  select field_id into _option_field_id
  from public.org_cost_field_options where id = new.option_id;
  if _option_field_id is distinct from new.field_id then
    raise exception 'This option does not belong to the selected field';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_trip_cost_field_value on public.trip_cost_field_values;
create trigger guard_trip_cost_field_value
  before insert or update on public.trip_cost_field_values
  for each row execute function public.guard_trip_cost_field_value();

-- -----------------------------------------------------------------------------
-- 7. RLS — trip_cost_field_values. Same "owner or editor member" rule as
--    trip_segments (stage21), since this is per-trip content, not org
--    content.
-- -----------------------------------------------------------------------------

alter table public.trip_cost_field_values enable row level security;

drop policy if exists "trip_cost_field_values_member_select" on public.trip_cost_field_values;
drop policy if exists "trip_cost_field_values_editor_write" on public.trip_cost_field_values;

create policy "trip_cost_field_values_member_select" on public.trip_cost_field_values
  for select using (
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

create policy "trip_cost_field_values_editor_write" on public.trip_cost_field_values
  for all
  using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where (m->>'user_id' = auth.uid()::text or m->>'userId' = auth.uid()::text)
              and m->>'role' in ('owner', 'editor')
          )
        )
    )
  )
  with check (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_id
        and (
          i.owner_id = auth.uid()
          or exists (
            select 1 from jsonb_array_elements(i.members) as m
            where (m->>'user_id' = auth.uid()::text or m->>'userId' = auth.uid()::text)
              and m->>'role' in ('owner', 'editor')
          )
        )
    )
  );

-- -----------------------------------------------------------------------------
-- 8. expenses.cost_center_code — the snapshot column (see header comment for
--    why this is a snapshot, not a live join).
-- -----------------------------------------------------------------------------

alter table public.expenses
  add column if not exists cost_center_code text;

comment on column public.expenses.cost_center_code is
  'Snapshotted at submit/resubmit time from the trip''s org cost-tracking '
  'fields (org_cost_fields/trip_cost_field_values) — deliberately NOT '
  'live-joined, so correcting a trip''s cost-center assignment later never '
  'silently changes which account an already-submitted/approved expense '
  'posts to. Editing an option''s code later is therefore forward-looking '
  'only (affects the next submit/resubmit or live preview), never '
  'retroactive. Null for personal trips, orgs with no generated field '
  'configured, or a trip with an incomplete field assignment at submit time.';

-- -----------------------------------------------------------------------------
-- 9. Resolution — one core function, two callers: the live-preview RPC
--    (called from Flutter with in-memory, not-yet-persisted selections) and
--    the expense-submit trigger (called with a trip's persisted selections).
-- -----------------------------------------------------------------------------

-- Core: resolve a code from an org + an explicit selection map. SECURITY
-- INVOKER (the default) is deliberate — RLS on org_cost_fields/options
-- already gates this correctly for any caller (an org member sees their
-- org's real fields; anyone else sees nothing and gets null back), so this
-- is safe to expose directly as an RPC.
create or replace function public.resolve_org_cost_center_code(
  p_org_id     uuid,
  p_selections jsonb   -- {"<field_id>": "<option_id>", ...}
) returns text
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  _generated_field_id uuid;
  _separator           text;
  _source                record;
  _option_id              uuid;
  _code                     text;
  _parts                     text[] := array[]::text[];
begin
  select id, separator into _generated_field_id, _separator
  from public.org_cost_fields
  where org_id = p_org_id and field_type = 'generated'
  limit 1;

  if _generated_field_id is null then
    return null;  -- org hasn't configured a generated cost-center field
  end if;

  for _source in
    select source_field_id
    from public.org_cost_field_sources
    where generated_field_id = _generated_field_id
    order by position
  loop
    _option_id := nullif(p_selections ->> _source.source_field_id::text, '')::uuid;
    if _option_id is null then
      return null;  -- incomplete assignment — can't resolve yet
    end if;

    select code into _code
    from public.org_cost_field_options
    where id = _option_id and field_id = _source.source_field_id;

    if _code is null then
      return null;  -- option missing/invalid for this field
    end if;

    _parts := array_append(_parts, _code);
  end loop;

  if array_length(_parts, 1) is null then
    return null;  -- generated field configured with zero sources
  end if;

  return array_to_string(_parts, _separator);
end;
$$;

grant execute on function public.resolve_org_cost_center_code(uuid, jsonb) to authenticated;

-- Wrapper: resolve directly from a saved trip's persisted assignments.
-- SECURITY DEFINER, deliberately — this is internal plumbing for the
-- expense-submit trigger below and must resolve correctly regardless of the
-- submitting payer's own row-level visibility into every field/option row.
-- EXECUTE is revoked from PUBLIC/authenticated: exposing it as a public RPC
-- would let any authenticated user probe an arbitrary itinerary_id and learn
-- another org's cost-center string for it, bypassing RLS. It's only ever
-- called from inside set_expense_cost_center_code() below.
create or replace function public.resolve_trip_cost_center_code(p_itinerary_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  _org_id     uuid;
  _selections jsonb;
begin
  select org_id into _org_id from public.itineraries where id = p_itinerary_id;
  if _org_id is null then
    return null;
  end if;

  select coalesce(jsonb_object_agg(field_id::text, option_id::text), '{}'::jsonb)
    into _selections
  from public.trip_cost_field_values
  where itinerary_id = p_itinerary_id;

  return public.resolve_org_cost_center_code(_org_id, _selections);
end;
$$;

revoke execute on function public.resolve_trip_cost_center_code(uuid) from public, authenticated;

-- The trigger itself: fires only on the submit/resubmit transition (same
-- transition submitted_at already tracks), so it composes cleanly with
-- guard_expense_review_fields (stage29) — they touch disjoint columns.
create or replace function public.set_expense_cost_center_code()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.approval_status = 'pending'
     and new.approval_status is distinct from old.approval_status then
    new.cost_center_code := public.resolve_trip_cost_center_code(new.itinerary_id);
  end if;
  return new;
end;
$$;

drop trigger if exists set_expense_cost_center_code on public.expenses;
create trigger set_expense_cost_center_code
  before update on public.expenses
  for each row execute function public.set_expense_cost_center_code();
