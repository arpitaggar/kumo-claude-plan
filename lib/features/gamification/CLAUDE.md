# lib/features/gamification

Added 2026-08-11 — loads only when working under lib/features/gamification/. Carried on `docs/DEVELOPMENT_ROADMAP.md`'s "What Remains" table since the original v1.0 brief, picked up as the next self-contained feature (not blocked by anything external, unlike Stripe/B2B-portal/Concierge-AI).

### XP, levels, and badges

**Migrations:** `docs/supabase_migrations/stage40_gamification.sql`.
Must be run in Supabase SQL editor before deploying the corresponding app build.

#### Database schema

`public.xp_events` — one append-only row per XP award: `user_id`, `amount`, `reason` (human-readable, e.g. "Completed a trip"), `source_type` (`trip_created`/`trip_completed`/`post_published`/`post_liked`/`follower_gained`/`comment_posted`), `source_id`, `created_at`. A user's current total is `sum(amount)` over their own rows — not a mutable counter column — same shape as `profile_status` (stage21).

RLS has **no insert policy at all** — every row is written by a `SECURITY DEFINER` trigger function, never a direct client insert, exactly like `public.notifications` (stage37):
- `award_xp_on_trip_created` (on `itineraries` insert) — recipient is `owner_id`.
- `award_xp_on_trip_completed` (on `itineraries` update of `status`, only when it transitions *to* `completed`) — recipient is `owner_id`.
- `award_xp_on_post_published` (on `itinerary_posts` insert) — recipient is `author_id`.
- `award_xp_on_post_liked` (on `post_likes` insert) — recipient is the post's author (looked up), skipped for a self-like.
- `award_xp_on_follower_gained` (on `follows` insert) — recipient is `followee_id`.
- `award_xp_on_comment_posted` (on `post_comments` insert) — recipient is `author_id` (the commenter).

**Anti-cheat is a unique index, not a rate-limit trigger:** `xp_events_dedup_idx` on `(user_id, source_type, source_id)`, and every trigger `insert ... on conflict (...) do nothing`. `source_id` is chosen per trigger so the same real-world event can never award twice — a trip's/post's/comment's own primary key for the one-shot events, and a `<target>:<actor>` pair for likes/follows so toggling (unlike/relike, unfollow/refollow, or flipping a trip's status back and forth) can't be farmed.

`add_expense_usecase.dart` is **deliberately not wired up** — unlike posts/likes/follows/comments, expenses have no rate limit anywhere in this schema, so an expense-XP trigger would be trivially farmable by spamming tiny expenses.

#### Flutter layer

Standard Clean Architecture layers, all read-only — **no existing mutation code path anywhere in the app changes for this feature.** `XpEvent` entity, `GamificationRepository`/`GamificationRemoteDataSource` (one bounded fetch, 500 rows, newest-first — both the summary and "recent activity" are derived from this single fetch), `FetchXpEventsUseCase`.

- **`XpSummary`** (`domain/entities/xp_summary.dart`) — computed client-side via `XpSummary.fromEvents(events)`: sums `amount` into `totalXp`, counts each `sourceType`. `level`/`xpIntoLevel`/`xpToNextLevel` are pure arithmetic on `totalXp` (100 XP per level) — no separate level storage.
- **`GamificationBadge`** (`domain/entities/gamification_badge.dart`) — named `GamificationBadge`, not bare `Badge`, to avoid colliding with `flutter/material.dart`'s own `Badge` widget. A fixed `static const all` catalog of 8 presets (metric + threshold), same preset-list shape as `TripTheme.all`. **No `badges`/`user_badges` table exists server-side** — `isEarnedBy(XpSummary)` is derived fresh every time, not stored.
- **`xpEventsProvider`**/`xpSummaryProvider` (`presentation/providers/gamification_provider.dart`) — both `.autoDispose`. This feature has exactly one consumer surface (Profile + Achievements), so re-fetching fresh on each visit was simpler and safer than manually wiring `ref.invalidate` into the 6 award-triggering call sites scattered across the itinerary/social features. No realtime.
- **`BadgeUnlockNotifier`** (`presentation/providers/badge_unlock_notifier.dart`) — structural mirror of `OnboardingNotifier`/`WorkModeNotifier`: per-user `SharedPreferences` key (`badges_seen_<uid>`) tracking which badges this user has already been shown a celebration for. `checkForNewBadges(summary)` returns only the newly-crossed subset.
- **`GamificationCard`** (`presentation/widgets/gamification_card.dart`) — inserted into `profile_page.dart` directly after `_StatsCard`. Uses `ref.listen` on `xpSummaryProvider` (not a `postFrameCallback`) to trigger `checkForNewBadges` and show `showBadgeUnlockDialog` — Riverpod's own supported way to run a side effect from a widget's `build()` safely outside the build phase.
- **`AchievementsPage`** (`/achievements`, pushed from the card) — level/XP header, the full 8-badge grid (locked badges greyed out with their threshold in a tooltip), and the 10 most recent XP events.

#### Key design decisions

- **XP is awarded entirely by database triggers, not client-side usecase calls.** This is also the anti-cheat story for free — a client can no more award itself XP than it can fabricate a "so-and-so liked your post" notification.
- **Badges are computed client-side from the XP ledger, not stored server-side.** Avoids a second `badges`/`user_badges` table that could drift out of sync with the events that should have earned them; "earned" is always a pure function of the same data the level/total already come from.
- **No push notification or persisted `notifications` row for a badge unlock** — in-app celebration only (`showBadgeUnlockDialog`), a deliberate scope trim to avoid touching the `notifications` table/`NotificationType` enum/`send-social-push` for this pass. Revisit only if badge unlocks turn out to need to reach a user who isn't in the app at the moment they cross a threshold.
- **Expenses are excluded from XP sources** — see the schema section above; revisit only if expenses ever gain a rate limit for other reasons.
- **Trip completion dedups via the trip's own id**, so a user cannot flip a trip's status `active ⇄ completed` repeatedly to farm the 30 XP award more than once.
