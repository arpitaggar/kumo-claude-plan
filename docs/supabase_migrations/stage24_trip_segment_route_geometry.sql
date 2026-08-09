-- =============================================================================
-- Stage 24 — Real road/walking route geometry for trip segments
-- Caches a routed path (fetched client-side from OSRM or Google Directions,
-- see lib/core/routing/) on the segment row so the Route tab doesn't refetch
-- it on every render and every trip member sees the same drawn route.
-- Safe to re-run: uses ADD COLUMN IF NOT EXISTS.
-- =============================================================================

alter table public.trip_segments
  add column if not exists route_geometry jsonb;

comment on column public.trip_segments.route_geometry is
  'Nullable array of [lat, lng] pairs tracing the real road/footpath route '
  'for car/motorcycle/bus/walk segments, fetched via OSRM or Google '
  'Directions (see lib/core/routing/). Null means "not fetched yet" or '
  '"not a routable mode" — the client falls back to a straight/curved line.';
