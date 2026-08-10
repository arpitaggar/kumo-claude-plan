-- =============================================================================
-- Stage 36 — Unpublish/delete a post
-- Safe to re-run: uses DROP POLICY IF EXISTS / CREATE POLICY.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- itinerary_posts was insert-only from stage22 ("immutable once written:
-- insert-only, no update/delete policy for v1 — unpublishing/deleting a post
-- is deferred"). Adding delete only, still no update policy — a post stays
-- an immutable snapshot right up until its author removes it outright.
--
-- No other cleanup needed: post_likes has `on delete cascade` on post_id
-- (stage22), and both itinerary_posts.forked_from_post_id (self-FK, stage22)
-- and itineraries.origin_post_id (stage22) are `on delete set null` — a
-- forked post or itinerary silently loses its "remixed from" lineage
-- pointer instead of being blocked or cascade-deleted itself.
-- -----------------------------------------------------------------------------

drop policy if exists "itinerary_posts_author_delete" on public.itinerary_posts;

create policy "itinerary_posts_author_delete" on public.itinerary_posts
  for delete using (author_id = auth.uid());
