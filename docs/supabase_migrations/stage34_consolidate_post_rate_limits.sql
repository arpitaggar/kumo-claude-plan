-- =============================================================================
-- Stage 34 — Consolidate itinerary_posts' two rate-limit triggers into one
-- (2026-08-09 second scalability-audit pass, docs/SCALABILITY_AUDIT.md
-- SCALE-013). Safe to re-run: uses CREATE OR REPLACE / DROP IF EXISTS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- [SCALE-013] stage33 added itinerary_posts_rate_limit (a 20/hour cap)
-- without noticing itinerary_posts already had guard_publish_rate_limit (a
-- 30-second cooldown, stage23/SEC-... publish-rate-limit finding) on the
-- same table. Both are BEFORE INSERT triggers running their own
-- `SELECT ... FROM itinerary_posts WHERE author_id = ... AND created_at >
-- ...` — each index-backed individually (itinerary_posts_author_id_idx,
-- stage22), so neither was a correctness bug, but every publish paid for
-- two near-identical index range scans instead of one, and it left two
-- separate rate-limit mechanisms for a future reader to reconcile instead
-- of one. Fix: fold the hourly cap into guard_publish_rate_limit (the
-- trigger stage23 already wired up) and drop the redundant second
-- trigger/function stage33 added.
-- -----------------------------------------------------------------------------

create or replace function public.guard_publish_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.itinerary_posts
    where author_id = new.author_id
      and created_at > now() - interval '30 seconds'
  ) then
    raise exception 'Please wait a moment before publishing again';
  end if;

  if (
    select count(*) from public.itinerary_posts
    where author_id = new.author_id and created_at > now() - interval '1 hour'
  ) >= 20 then
    raise exception 'Rate limit exceeded: too many trips published in a short time. Please slow down.';
  end if;

  return new;
end;
$$;

drop trigger if exists itinerary_posts_rate_limit on public.itinerary_posts;
drop function if exists public.check_itinerary_posts_rate_limit();
