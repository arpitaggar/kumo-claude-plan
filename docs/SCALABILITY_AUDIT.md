# Kumo — Scalability Audit

**Last Updated:** 2026-08-09
**Scope:** All 32 Supabase migrations (`docs/supabase_migrations/`), all Edge Functions (`supabase/functions/`), the social feed / chat / notification data layers (the highest-traffic surfaces), and Supabase Realtime usage across every watched table.
**Question asked:** Could this architecture scale at the rate of Instagram or a major social platform?

**2026-08-09 remediation pass:** every finding classified as an "easy fix" (code/query/config change, no new infrastructure) is now fixed — SCALE-001, 003, 004, 005, 008, 009. See each entry's **Status** line below and `docs/supabase_migrations/stage33_social_feed_scale.sql`. SCALE-002, 006, 007, 010 remain open by design (real infrastructure additions, not justified until the traffic that would need them actually shows up — see the Verdict). SCALE-011 is a Supabase dashboard toggle on the live project, outside what a code change can do; SCALE-012 is a provider swap/self-host decision, not made here.

**2026-08-09 second pass:** re-audited with the benefit of having just built the stage33 fixes and separately read the whole organization/work-mode schema in depth (during an unrelated test-coverage pass) — checking whether the fixes themselves introduced anything, and whether that schema (not in the original audit's primary scope) holds up. Found and fixed one real issue the first pass missed (SCALE-013); found and documented one real issue in the *new* pagination code itself (SCALE-014); otherwise confirmed clean. See both entries below, plus a `docs/supabase_migrations/stage34_consolidate_post_rate_limits.sql` migration — **✅ run against the live database (2026-08-11).**

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

- **Status:** 📋 Decided (2026-08-11) — leave as-is. Asked the user directly (swap to a paid provider vs. self-host OSRM vs. accept as-is); chose to accept.
- `NominatimGeocodingService`'s self-imposed 1 req/sec throttle and `OsrmRoutingService`'s public OSRM demo server (confirmed in the 2026-08-09 route-geometry audit, `lib/core/maps/CLAUDE.md`) are free/evaluation-tier services with no production SLA. Both already degrade gracefully today — geocoding just throttles rather than erroring, and routing falls back to a straight/curved line on failure with no user-facing error — so there's no live bug being accepted here, just a known ceiling on routing/geocoding reliability at real traffic. Revisit if either service's rate limit is actually hit in practice, not preemptively.

### [SCALE-013] `itinerary_posts` ended up with two overlapping rate-limit triggers

- **Status:** ✅ Fixed (2026-08-09, second pass) — `docs/supabase_migrations/stage34_consolidate_post_rate_limits.sql`. **✅ Run against the live database (2026-08-11).**
- **Found by:** re-checking the SCALE-003 fix itself, not a fresh area.
- **Cause:** The first pass's SCALE-003 write-up said "no rate limiting on likes/follows/posts" and added `itinerary_posts_rate_limit` (a 20/hour cap) via stage33 — without noticing `itinerary_posts` already had `guard_publish_rate_limit` (a 30-second cooldown) from stage23. Neither was wrong on its own — both are `BEFORE INSERT` triggers doing an index-backed `SELECT ... WHERE author_id = ... AND created_at > ...` against `itinerary_posts_author_id_idx` — but every publish paid for two near-identical index range scans instead of one, and the schema was left with two separate rate-limit mechanisms on the same table for a future reader to reconcile. Low severity (both checks are cheap), but a real, avoidable redundancy, and worth correcting the original finding's claim that no protection existed at all for posts.
- **Fix applied:** Folded the hourly cap into `guard_publish_rate_limit` (the function stage23's trigger already calls) and dropped stage33's separate trigger/function. One trigger, one function, both checks.

### [SCALE-014] `PostFeedNotifier`'s "Load more" accumulates every loaded page in memory forever

- **Status:** ✅ Fixed (2026-08-10) — `lib/features/social/presentation/providers/social_provider.dart`. Was explicitly left as "documented, not fixed" here since it's a product/UX trade-off, not a pure bug — user was asked directly and chose to cap it.
- **Found by:** re-reading the SCALE-009 pagination fix itself, since it's new code the first pass never had a chance to scrutinize.
- **Location:** `PostFeedNotifier.loadMore()`, `lib/features/social/presentation/providers/social_provider.dart`.
- **Cause:** `state = PostFeedLoaded([...current.posts, ...nextPage], ...)` — every "Load more" tap concatenated onto the existing list, and nothing ever evicted earlier pages. `DiscoverPage`'s `ListView.separated` still renders lazily (only on-screen `PostCard`s get built), so this was never a UI-jank problem — it was Dart-heap memory for every `ItineraryPost` (each carrying its full snapshotted `items`/`segments`) staying resident for as long as the provider lived.
- **Breaks at:** a user would need to page through hundreds of "Load more" taps in one session before this meaningfully mattered — a real but distant threshold, not urgent at any scale this app is actually at. Fixed anyway now that a decision was made either way.
- **Fix applied:** capped at `kMaxFeedWindowPosts` (10 pages / 200 posts) — once `loadMore()`'s concatenated list exceeds that, the earliest-loaded page is evicted from the front. The pagination cursor (`current.posts.last.createdAt`) always derives from the tail, so trimming the front never disturbs it. Traded away: scrolling back up past the evicted window shows a fresh reload from the top instead of the exact posts scrolled past earlier — an accepted, explicitly-chosen trade-off, not an oversight.

---

## Verdict

This architecture would comfortably scale to a genuinely successful consumer app — tens of thousands to low hundreds of thousands of users — with no redesign, because its two highest-leverage decisions are already correct: the social feed is pull-based (fan-out-on-read), and Realtime subscriptions are row-scoped rather than table-wide firehoses. Both are exactly what a system built for actual Instagram scale still does at the edges.

It would **not** reach real Instagram-tier scale (hundreds of millions of users, sustained viral fan-out) without redesigning three specific subsystems — not the whole app:

1. **Replace the synchronous like-counter trigger** (SCALE-001) with an async/approximate counting scheme — this is the earliest, cheapest, and most urgent fix, since it can degrade badly at a traffic level far below the rest of this list.
2. **Introduce real queue/job infrastructure** (SCALE-002) — the single biggest structural gap. Nothing today can be deferred off the request path, which caps every future fan-out-heavy feature, not just the ones that exist now.
3. **Migrate the feed/chat realtime firehose off Supabase Realtime's connection model** (SCALE-010) once its per-project connection ceiling is actually hit — a "graduate to different infrastructure" problem, not a bug.

Everything else in this audit (SCALE-003 through SCALE-009, SCALE-011 through SCALE-014) is either a known, already-flagged, low-effort fix — SCALE-001, 003, 004, 008, 009, 013, 014 are now fixed, and SCALE-005 is code-complete pending an ops toggle — or simply not a live problem at this app's actual data shapes (trip-sized groups, not public-broadcast-sized audiences). Building for Instagram-scale load today, before there's Instagram-scale traffic, would itself be a mistake — the standard advice (add read replicas/connection pooling first, then queue infrastructure, then counter/fan-out redesigns, roughly in that order of need) holds here.

## Second-pass confirmations (2026-08-09) — checked, not just assumed

A few things worth confirming explicitly rather than re-deriving from scratch each audit, since they held up under closer inspection:

- **The RLS helper functions from stage31** (`is_org_member`, `is_org_admin`, and siblings) **are correctly marked `stable`**, letting Postgres's planner treat them efficiently within a single query rather than as opaque volatile calls.
- **The organization/work-mode schema (stage28-30) is thoroughly indexed** — every FK lookup pattern the app actually queries (`org_members` by `org_id`, `org_cost_fields` by `org_id`, `org_cost_field_options` by `field_id`) is backed by an index, almost entirely *implicitly* via `unique (org_id, ...)`-style constraints rather than a hand-added `create index`. This is exactly the "real join table with proper indexes" pattern SCALE-006 already credited it for — confirmed correct on a second, closer look, not just asserted.
- **`sync_post_like_count` (SCALE-001) was the only synchronous shared-counter hot-row pattern anywhere in the schema** — checked all 34 migrations for the same shape (`for each row execute function` triggers doing an `UPDATE ... SET x = x ± 1` against a row other than the one being written) and found nothing else like it. Chat's read-receipt tracking, for comparison, uses per-row appends (an array column + a `message_reads` table), not a shared counter — no equivalent risk there.

## Verification (2026-08-09 remediation pass)

`flutter analyze --no-fatal-infos` — 144 issues, all info-level, zero warnings/errors. `flutter test` — 577/577 passing (35 new tests: pagination/rate-limit-adjacent repository and provider coverage, plus `resizedImageUrl`/`transformObjectUrl`). New migration `docs/supabase_migrations/stage33_social_feed_scale.sql` — ✅ run against the live database (2026-08-09). SCALE-001/003/004/008/009's fixes are now live in production; SCALE-005 (image resizing) is still gated off client-side behind `kImageResizingEnabled = false` regardless of the migration, per that finding's own note.

## Verification (2026-08-09 second pass)

New migration `docs/supabase_migrations/stage34_consolidate_post_rate_limits.sql` (SCALE-013) — SQL-only change, no Dart touched, so no analyze/test delta to report; **✅ run against the live database (2026-08-11).**

## Third pass (2026-08-11) — reviewed the new Work Mode feature

No new findings. `visibleItinerariesProvider` (Home/Trips filtering) is pure in-memory `.where()` over a list `itineraryListProvider` had already fetched for other reasons — zero additional queries. `isWorkModeAvailableProvider`/`currentWorkOrgProvider` read the existing, already-cached `myOrganizationsProvider` (a one-shot `FutureProvider`, same as before this feature) rather than issuing a new fetch, and `WorkModeBanner` being mounted in `KumoShell` on every screen doesn't change that — it's a cheap re-read of cached provider state, not a re-query. No new Realtime subscriptions, no new hot paths, no N+1. Confirms the rest of this audit's scope is unaffected by this feature.

## Fourth pass (2026-08-13) — gamification (catch-up) and the Hitchhiker/age-gate feature

Gamification (Stage 23, shipped 2026-08-11) was already reviewed for scalability at the time — `docs/Checklist.md`'s "Audit round: gamification review" entry — but that review was never logged in this file; noting it here for the record. No finding: the XP rate-limit check added by `stage41_gamification_rate_limits.sql` is one indexed-prefix query per trip create/complete (`user_id` + time-window narrows via the existing `xp_events_user_id_created_at_idx`), not worth a dedicated index at this table's expected volume.

Reviewed `stage44_age_gate.sql`/`stage45_hitchhikers.sql` (2026-08-12) fresh. No scalability finding — `enforce_signup_age_gate()` is a `BEFORE INSERT` trigger doing constant-time arithmetic on a single row, no additional query. `hitchhiker_get_trip_view()` caps its `messages` read at 100 rows (same bound as the rest of the app's chat reads) and reads `itinerary_suggestions` unbounded, but that table is scoped to one trip's Hitchhiker-submitted items — no plausible growth path to a hot table at this app's scale. `trip_hitchhikers` itself is Captain-added only (no self-serve growth vector). The one real finding from this pair — no rate limit on the token-authenticated `hitchhiker_send_message`/`hitchhiker_suggest_item` RPCs — is an abuse/anti-cheat concern, not a scale one; tracked as SEC-034 in `docs/SECURITY_AUDIT.md` rather than duplicated here.
