# Kumo — Scalability Audit

**Last Updated:** 2026-08-09
**Scope:** All 32 Supabase migrations (`docs/supabase_migrations/`), all Edge Functions (`supabase/functions/`), the social feed / chat / notification data layers (the highest-traffic surfaces), and Supabase Realtime usage across every watched table.
**Question asked:** Could this architecture scale at the rate of Instagram or a major social platform?

**2026-08-09 remediation pass:** every finding classified as an "easy fix" (code/query/config change, no new infrastructure) is now fixed — SCALE-001, 003, 004, 005, 008, 009. See each entry's **Status** line below and `docs/supabase_migrations/stage33_social_feed_scale.sql`. SCALE-002, 006, 007, 010 remain open by design (real infrastructure additions, not justified until the traffic that would need them actually shows up — see the Verdict). SCALE-011 is a Supabase dashboard toggle on the live project, outside what a code change can do; SCALE-012 is a provider swap/self-host decision, not made here.

**Short answer up front:** No — not without three specific subsystem rewrites, and that's expected, not a failure. Instagram itself ran on a single Postgres primary for its first ~2 years and 30M+ users before it needed to shard. This app is a single-Postgres-instance design (via Supabase) with no background job/queue layer — the right shape for its actual current scale (trip-planning groups, not a public global feed), and the wrong shape for hundreds of millions of DAU and viral fan-out. The findings below separate "will break embarrassingly early" from "correct today, would need a rewrite only at real Instagram-tier volume."

---

## Findings, prioritized by how early they'd actually break

### [SCALE-001] Hot-row like counter — the single earliest-breaking issue

- **Status:** ✅ Fixed (2026-08-09) — `docs/supabase_migrations/stage33_social_feed_scale.sql`.
- **Breaks at:** roughly hundreds of concurrent likes/sec on one popular post — nowhere near Instagram scale, well within reach of one moderately successful public post on this app.
- **Location:** `docs/supabase_migrations/stage22_social_feed.sql` — `sync_post_like_count()`, an `AFTER INSERT/DELETE` trigger on `post_likes`.
- **Cause:** Every like/unlike runs `UPDATE itinerary_posts SET like_count = like_count + 1 WHERE id = ...` synchronously against the *same single row*. Postgres MVCC means every concurrent writer to that row serializes on its row lock and creates a new dead tuple — a viral post becomes a lock-contention bottleneck and a vacuum/bloat problem on exactly the row getting the most attention, which is the worst possible place for it to happen.
- **Fix applied:** Dropped the trigger, function, and `like_count` column entirely (option (a) from the standard fix pattern — count `post_likes` rows on read via PostgREST's embedded-resource count, `post_likes(count)`, backed by a new `(user_id, created_at)` index). `ItineraryPostModel.fromJson` reads the embedded count instead of a stored column. Option (b) (async/sharded counter) is the eventual next step if read-time counting itself becomes the bottleneck, but requires SCALE-002's queue infrastructure first — not justified yet.

### [SCALE-002] No background job/queue infrastructure exists anywhere

- **Breaks at:** this isn't a traffic threshold — it's a structural absence that caps how *any* future fan-out-heavy feature can scale, regardless of load.
- **Location:** confirmed by search — no `pg_cron`, no queue extension, no async task runner anywhere in the schema or Edge Functions.
- **Cause:** Every piece of server-side work in this app is either a synchronous Postgres trigger (fires inline with the write) or a synchronous Edge Function invocation (fires inline with the request, and the Flutter client `await`s it). There is no mechanism to defer or batch expensive work — notifying thousands of followers of a new post, resizing an image, recomputing an approximate counter — outside the request path.
- **Standard fix pattern:** Introduce a real queue (Supabase's `pgmq` extension, or an external queue) once any single feature needs fan-out past what a synchronous request can do in its time budget. This is the biggest real gap for scaling *toward* social-media traffic — everything else in this audit is a symptom of not having this yet.

### [SCALE-003] No rate limiting on likes/follows/posts

- **Status:** ✅ Fixed (2026-08-09) — `docs/supabase_migrations/stage33_social_feed_scale.sql`.
- **Breaks at:** this is an abuse-surface gap, not a load one — it becomes a problem the moment the app is public and interesting enough to be worth spamming, which can happen at very small scale.
- **Location:** `stage23_security_hardening.sql`'s own migration comment explicitly defers this ("Full rate limiting for likes/follows is deferred"). Only `generate-itinerary` (AI cost) and `inbound-trip-email` (20/hr) have guards today.
- **Fix applied:** `BEFORE INSERT` trigger-based rate limits on `post_likes` (60/min), `follows` (30/min), and `itinerary_posts` (20/hour), same counting approach as `generation_requests` (SEC-009) — these are direct client inserts with no Edge Function intermediary, so a DB trigger is the only enforcement point available. Thresholds are deliberately generous (anti-spam, not pacing).

### [SCALE-004] Feed fan-out is the right model, but the follow-list has no cap

- **Status:** ✅ Fixed (2026-08-09).
- **Breaks at:** thousands of follows for a single account — a real number for a public social app, not for this one today.
- **Location:** `SocialRemoteDataSourceImpl.fetchFeed`.
- **Cause:** Correctly pull-based (fan-out-on-read: fetch `follows` for the viewer, then `itinerary_posts WHERE author_id IN (followeeIds) LIMIT 100`) — this is the right default and avoids the classic "celebrity account" fan-out-on-write explosion. But the `followee_id` query itself has no limit, so a very-widely-followed account sends an unbounded `IN (...)` list on every feed load.
- **Fix applied:** Capped the `follows` fetch to the 1000 most-recently-followed accounts per feed load (`_maxFolloweesPerFeed`). Pre-materializing a feed table remains the eventual next step if follow-graph sizes ever actually justify it — not done here.

### [SCALE-005] No image resizing/thumbnailing/CDN variants

- **Status:** 🔧 Code-complete, gated off (2026-08-09) — `lib/core/network/supabase_image_url.dart`.
- **Breaks at:** meaningfully high image-request volume — avatars and chat attachments are always served as full-size originals today.
- **Location:** avatar upload / chat attachment paths, Supabase Storage.
- **Fix applied:** `resizedImageUrl()` rewrites a Supabase Storage public object URL to request a width/quality-limited variant via Supabase's image-transform endpoint, wired into every avatar (`profile_page.dart`, `public_profile_page.dart`, `post_card.dart`, `edit_profile_page.dart`, `chat_page.dart`'s read-receipt row) and the chat attachment bubble thumbnail (the full-screen viewer still requests the original, correctly). **Gated behind `kImageResizingEnabled = false`** — image transformation is a paid-tier Supabase add-on, and its behavior when the add-on isn't enabled (error vs. serving the original) isn't something to assume without checking against the live project first. Flip the flag once the add-on is confirmed enabled in the Supabase dashboard; until then this is a safe no-op (every image renders exactly as it does today).

### [SCALE-006] `jsonb_array_elements(members)` RLS scans — O(n) per row, not index-friendly

- **Breaks at:** only if a "members" group (trip members, org members) ever grew into the hundreds+ — not expected for this app's domain.
- **Location:** 8+ migration files use `EXISTS (... jsonb_array_elements(members) ...)` for itinerary/expense/rating/message/packing RLS, instead of a real join table.
- **Note:** already flagged in the prior security audit for key-casing reasons, not scale — included here for completeness. Notably, the *newer* work-mode code (`org_members`, stage28) already fixed this pattern by using a real join table with proper indexes. Not a live problem today.

### [SCALE-007] Push notification fan-out is synchronous, but appropriately scoped to this app's domain

- **Breaks at:** hundreds-to-low-thousands of recipients in one trip's chat — a number this app's actual group sizes (trip members, not public broadcast) will never approach.
- **Location:** `supabase/functions/send-message-push` — uses `Promise.all` (concurrent, not serial — correctly done), but the whole fan-out happens inside one Edge Function invocation the client awaits.
- **Note:** this is fine as designed. It would only become a problem if the app grew a "broadcast to everyone" feature, which it doesn't have.

### [SCALE-008] Explore search is a 50-post client-side substring filter, not a search index

- **Status:** ✅ Fixed (2026-08-09) — `docs/supabase_migrations/stage33_social_feed_scale.sql`.
- **Location:** `SocialRemoteDataSourceImpl.fetchExplore`.
- **Cause:** Fetches the most recent 50 posts server-side, then does client-side `.toLowerCase().contains()` filtering. This is a **functional** gap, not just a performance one — searching "Tokyo" only ever searches the 50 newest posts globally, regardless of corpus size, even today.
- **Fix applied:** `pg_trgm` extension + GIN indexes on `title`/`description`, queried server-side via `.or('title.ilike.%q%,description.ilike.%q%')` — searches the whole table, not just whatever page happened to be fetched. Chosen over `tsvector` full-text search specifically to preserve the existing substring-match UX (partial-word matches) rather than switch to word/stem-based matching.

### [SCALE-009] No cursor-based pagination on feed/explore fetches

- **Status:** ✅ Fixed (2026-08-09).
- **Location:** same file as above — both `fetchFeed`/`fetchExplore` take a flat `.limit()` with no `range()`/before-cursor support.
- **Fix applied:** Keyset pagination (`before: DateTime?` → `created_at < before`) threaded through the datasource → repository → usecase → a new `PostFeedNotifier` (replacing the old flat `FutureProvider`s) that tracks `hasMore`/accumulates pages, plus a "Load more" footer wired into `DiscoverPage`'s post list for both the Explore and Following tabs. `hasMore` is a heuristic (last page came back full-sized), not a server-confirmed total — sufficient for "show the button or don't."

### [SCALE-010] Realtime subscriptions are correctly row-scoped — the ceiling here is the platform, not the code

- **Location:** all 7 watched tables (itineraries, chat, expenses, packing, trip_segments, ratings, plus the newer routing work) use `.eq('itinerary_id', ...)`-scoped streams, not table-wide firehoses.
- **Note:** this is done right. The real limit is Supabase Realtime's own documented concurrent-connection ceiling per project (tens-of-thousands range depending on plan) — hitting that means migrating off Supabase Realtime for the highest-traffic surfaces, not fixing an app-code defect.

### [SCALE-011] Single Postgres instance — no read replicas, sharding, or partitioning anywhere

- **Note:** expected at this stage. Supabase supports read replicas and connection pooling (PgBouncer) as a config change before any schema redesign is needed — this is the first, cheapest lever, well before sharding/partitioning would be justified.

### [SCALE-012] External dependencies are not production-scale services (already known)

- `NominatimGeocodingService`'s self-imposed 1 req/sec throttle and `OsrmRoutingService`'s public OSRM demo server (confirmed in the 2026-08-09 route-geometry audit, `lib/core/maps/CLAUDE.md`) are free/evaluation-tier services with no production SLA. Not re-derived here — carried forward as still true.

---

## Verdict

This architecture would comfortably scale to a genuinely successful consumer app — tens of thousands to low hundreds of thousands of users — with no redesign, because its two highest-leverage decisions are already correct: the social feed is pull-based (fan-out-on-read), and Realtime subscriptions are row-scoped rather than table-wide firehoses. Both are exactly what a system built for actual Instagram scale still does at the edges.

It would **not** reach real Instagram-tier scale (hundreds of millions of users, sustained viral fan-out) without redesigning three specific subsystems — not the whole app:

1. **Replace the synchronous like-counter trigger** (SCALE-001) with an async/approximate counting scheme — this is the earliest, cheapest, and most urgent fix, since it can degrade badly at a traffic level far below the rest of this list.
2. **Introduce real queue/job infrastructure** (SCALE-002) — the single biggest structural gap. Nothing today can be deferred off the request path, which caps every future fan-out-heavy feature, not just the ones that exist now.
3. **Migrate the feed/chat realtime firehose off Supabase Realtime's connection model** (SCALE-010) once its per-project connection ceiling is actually hit — a "graduate to different infrastructure" problem, not a bug.

Everything else in this audit (SCALE-003 through SCALE-009, SCALE-011, SCALE-012) is either a known, already-flagged, low-effort fix — SCALE-001, 003, 004, 008, 009 are now fixed, and SCALE-005 is code-complete pending an ops toggle — or simply not a live problem at this app's actual data shapes (trip-sized groups, not public-broadcast-sized audiences). Building for Instagram-scale load today, before there's Instagram-scale traffic, would itself be a mistake — the standard advice (add read replicas/connection pooling first, then queue infrastructure, then counter/fan-out redesigns, roughly in that order of need) holds here.

## Verification (2026-08-09 remediation pass)

`flutter analyze --no-fatal-infos` — 144 issues, all info-level, zero warnings/errors. `flutter test` — 577/577 passing (35 new tests: pagination/rate-limit-adjacent repository and provider coverage, plus `resizedImageUrl`/`transformObjectUrl`). New migration `docs/supabase_migrations/stage33_social_feed_scale.sql` — ✅ run against the live database (2026-08-09). SCALE-001/003/004/008/009's fixes are now live in production; SCALE-005 (image resizing) is still gated off client-side behind `kImageResizingEnabled = false` regardless of the migration, per that finding's own note.
