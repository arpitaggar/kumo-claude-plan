-- =============================================================================
-- Stage 25 — Per-segment visibility toggle for trip segments
-- Lets a trip member hide a leg from the Route tab's map (e.g. to declutter
-- a long trip) without deleting it — the segment card stays in the list
-- either way, with a toggle to show it again. Purely a display flag; it has
-- no effect on RLS, ordering, or any other segment field.
-- Safe to re-run: uses ADD COLUMN IF NOT EXISTS.
-- =============================================================================

alter table public.trip_segments
  add column if not exists is_visible boolean not null default true;

comment on column public.trip_segments.is_visible is
  'Whether this leg is drawn on the Route tab''s map. Toggled from the '
  'segment card; never affects the segment''s existence or order_index. '
  'Defaults true so every pre-existing segment stays visible.';
