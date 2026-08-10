# lib/features/notifications

Added 2026-08-10 — loads only when working under lib/features/notifications/. Second of three explicitly-deferred Stage 22 social-feed items (unpublish/delete was the first, see lib/features/social/ and Checklist.md; comments is the third, not yet built).

### Social notifications: in-app feed + push for likes, follows, new posts

**Migration:** `docs/supabase_migrations/stage37_social_notifications.sql`
Must be run in Supabase SQL editor before deploying the corresponding app build.

#### Database schema

`public.notifications` — one row per event: `recipient_id`, `actor_id`, denormalised `actor_name`/`actor_avatar_url` (same rationale as `itinerary_posts`' author fields — the feed renders with zero joins), `type` (`like`/`follow`/`new_post`), `post_id` + `post_title` (null for `follow`), `read_at`, `created_at`.

RLS has **no insert policy at all** — every row is written by a `SECURITY DEFINER` trigger function, never a direct client insert:
- `notify_on_post_like` (on `post_likes` insert) — recipient is the post's author, skipped for a self-like
- `notify_on_follow` (on `follows` insert) — recipient is the followee
- `notify_on_new_post` (on `itinerary_posts` insert) — fans out to the author's followers, capped at 1000 most-recently-followed (same bound `fetchFeed` already applies, stage33)

Update is allowed (`recipient_id = auth.uid()`) so mark-as-read doesn't need an RPC. `social_activity` was added as a `notification_preferences` category the same way stage19 added `chat_messages`: widen the check constraint, reissue `seed_notification_preferences`, backfill existing users.

#### Flutter layer

Standard Clean Architecture layers — `AppNotification` entity (`NotificationType` enum + `fromWire`), `NotificationsRepository`/`NotificationsRemoteDataSource` (one bounded `.stream()` watch, 50 rows, newest-first — backs the feed page, the unread badge, *and* the foreground watcher; not a fully paginated history, a deliberate scope trim), `WatchNotificationsUseCase`/`MarkNotificationsReadUseCase`.

- **`notificationFeedProvider`** (`presentation/providers/notifications_provider.dart`) — deliberately NOT `.autoDispose`, mounted once via `socialNotificationWatcherProvider` in `KumoShell` so it stays alive for the whole session, same as `chatMessageWatcherProvider`.
- **`unreadNotificationCountProvider`** — derived from the same feed, backs the bell badge in `DiscoverPage`'s `AppBar` (`Icons.notifications_outlined` → `/notifications`).
- **`NotificationsPage`** (`/notifications`) — marks everything read on open (deferred to a post-frame callback + a `build()`-time recheck, since `authNotifierProvider` may not have resolved by the very first frame in some launch orderings) and sets `notificationsPageActiveProvider` while visible so the foreground watcher doesn't double up with what's already live in the list.
- **`socialNotificationWatcherProvider`** — same split as `chatMessageWatcherProvider`: once real OS push owns a platform (Android always; iOS once `kIosPushReady`), this only fires while resumed.
- **`notificationText()`** (`presentation/widgets/notification_text.dart`) — single (title, body) copy source shared between the list tile and the push/local-notification watcher, so the two can't drift.

#### Push delivery — `supabase/functions/send-social-push`

Mirrors `send-message-push`'s Android-data-only / iOS-alert split (see `lib/features/chat/CLAUDE.md` for the fuller rationale). Invoked best-effort by `SocialRemoteDataSourceImpl` right after `toggleLike`(like)/`toggleFollow`(follow)/`publishItinerary` succeed. Re-derives the recipient(s) server-side from `post_likes`/`follows`/`itinerary_posts` rather than trusting the client, same posture `send-message-push` uses for its own recipient list — it does **not** read from `public.notifications`.

The FCM data payload's `kind` field (`'chat'` vs `'social'`) is shared infrastructure with the chat push path — `lib/core/notifications/push_message_handler.dart`'s background handler and `handleIosPushTap` both branch on it, and `NotificationService`'s local-notification payload uses the same `'<kind>:<id>'` convention (`'social:<actorId>'`) so `NotificationService._onTap` can route without a second tap callback.

**Required secret:** shared with `send-message-push` — `FIREBASE_SERVICE_ACCOUNT_KEY`.
**Deploy:** `supabase functions deploy send-social-push`

#### Key design decisions

- **Bounded feed, not paginated.** 50 rows via one realtime `.stream()` backs the page, badge, and watcher. Revisit if "Load more" is ever actually requested — the `PostFeedNotifier` keyset-pagination pattern in `lib/features/social/` is the template to follow.
- **All navigation targets the actor's profile (`/u/:actorId`).** No single-post detail route exists anywhere in the app (posts are only ever viewed inline in a feed) — every notification type, including `new_post`, routes to the actor's `PublicProfilePage` rather than inventing a post-detail screen just for this.
- **No unread count past the 50-row window.** A user with more than 50 unread notifications sees "the last 50, mark all read" — not an exact count. Acceptable for this app's scale; the same trade-off the scalability audit already accepted elsewhere (see `docs/SCALABILITY_AUDIT.md`).
