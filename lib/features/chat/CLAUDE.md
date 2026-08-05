# lib/features/chat

Migrated from the project root CLAUDE.md (2026-08-03 doctor cleanup) — loads only when working under lib/features/chat/. Push notification delivery is included here since it's chat-triggered, even though some of its code lives under lib/core/notifications/.

### Chat Upgrade, Dark Themes & Push Notification Foundation (Stage 19)

**Migration:** `docs/supabase_migrations/stage19_chat_upgrade.sql`  
Must be run in Supabase SQL editor before deploying the corresponding app build.

#### Database schema additions

- `messages.content` check constraint relaxed to `char_length between 0 and 4000` (attachment-only messages have no caption)
- `public.message_attachments` — one row per image/file attachment; `kind in ('image', 'file')`; RLS: readable by anyone who can read the parent message, insertable only by the message's own sender
- `chat-attachments` storage bucket — public read, writes restricted to the caller's own `{uid}/` prefix (same pattern as the Stage 18 `avatars` bucket)
- `public.message_reads` — per-user `(message_id, user_id, read_at)`; no direct client access, only through `SECURITY DEFINER` RPCs below. This sits alongside the existing `read_by text[]` array (Stage 15/16) rather than replacing it — `read_by` still drives the double-tick indicator, `message_reads` adds timestamped detail for the "who's seen this" view
- `notification_preferences` gains a `chat_messages` category (constraint updated); `profiles` gains `push_message_preview_enabled boolean default true`
- `public.push_tokens` — `(user_id, token, platform)` PK where `platform in ('ios', 'android')`; owner-all RLS

#### RPCs

- `mark_messages_read(p_itinerary_id)` — reissued to also upsert into `message_reads` alongside the existing `read_by` array append
- `get_message_read_receipts(p_message_id)` — sender-only; returns `(user_id, display_name, avatar_url, read_at)` for the long-press "message info" sheet
- `update_profile(...)` — reissued with a 14th param, `p_push_message_preview`; the old 13-param signature is explicitly dropped first (`create or replace` only matches identical parameter lists, so without the drop, Postgres would keep both as ambiguous overloads)
- `upsert_push_token(p_token, p_platform)` — single-row upsert on the `(user_id, token)` PK

#### Flutter layer

- **Chat UI (`lib/features/chat/presentation/pages/chat_page.dart`):** WhatsApp-style bottom-anchored message list with date dividers, photo attachment picker/viewer, long-press read-receipt bottom sheet
- **Entities:** `MessageAttachment` (`domain/entities/message_attachment.dart`), `MessageReadReceipt` (`domain/entities/message_read_receipt.dart`)
- **Notification Preferences page:** `chat_messages` push toggle added to the existing matrix; a separate "show message preview" toggle controls whether push/local notification bodies show the actual text or a generic "New message"
- **Dark themes:** see Theming System section above — three new themes added, including the app's first dark theme (Synthwave Tokyo)
- **App rename:** bundle/application ID changed to `com.cygnus.travelKumo` on both platforms (was needed to register a clean Firebase project)
- **Firebase project setup:** `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` added; `ios/Runner/AppDelegate.swift` calls `FirebaseApp.configure()`. This stage only wired up the Firebase *project* — actual push delivery (FCM token registration, the sending Edge Function, and iOS entitlements) was built out afterward, see below.


### Push Notification Delivery (Stage 19 extension)

Built on top of the Stage 19 Firebase project setup to actually deliver chat push notifications, rather than just showing a local notification while the app is open.

#### Architecture

- **Android:** data-only FCM messages throughout — no top-level FCM `notification` field — so `flutter_local_notifications` has full, consistent control over how a notification is displayed in every app state:
  - Foreground/backgrounded-but-alive → `chatMessageWatcherProvider`'s Realtime stream watch (`lib/features/chat/presentation/providers/chat_provider.dart`)
  - Backgrounded/killed → `firebaseMessagingBackgroundHandler` (`lib/core/notifications/push_message_handler.dart`), registered via `FirebaseMessaging.onBackgroundMessage` in `main.dart`, runs in a separate isolate and calls `flutter_local_notifications` directly
  - Both paths converge on the same tap callback (`NotificationService._onTap`), navigating to `/trip/:id/chat`
  - `_maybeNotify` in `chat_provider.dart` only fires the foreground/Realtime path when the app is actually resumed (`WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed`) — otherwise the backgrounded FCM handler would double up with it
- **iOS:** a real `apns.payload.aps.alert` block instead of data-only, sent from the same Edge Function. Apple gives silent/data-only background pushes no delivery guarantee — in particular they are not delivered once the user force-quits the app — so the Android approach of "app renders its own notification" doesn't transfer. An OS-displayed alert has no such gap. Tap handling for it is separate: `FirebaseMessaging.onMessageOpenedApp` + `getInitialMessage()`, wired in `main.dart`, calling `handleIosPushTap` in `push_message_handler.dart` (flutter_local_notifications is never involved on the alert path, so its tap callback can't cover it)
- **iOS is gated behind `kIosPushReady`** (`lib/core/notifications/push_config.dart`), currently `false`. Flip it once both are done:
  1. An APNs key is uploaded in the Firebase console (Project settings → Cloud Messaging → Apple app configuration)
  2. The Push Notifications capability is enabled for the Runner target in Xcode (regenerates the provisioning profile to include it)

  `ios/Runner/Runner.entitlements` (`aps-environment`) already exists and is wired into all three build configs via `CODE_SIGN_ENTITLEMENTS` in `project.pbxproj` — confirmed with a real `flutter build ios --no-codesign`. **Update (Stage 20):** this project used Swift Package Manager for all iOS plugin integration through Stage 19, with no CocoaPods involved. Adding `google_maps_flutter` for the pluggable map (see below) reintroduced CocoaPods — `google_maps_flutter_ios` ships only a `.podspec`, no `Package.swift`, so it doesn't support SPM. `ios/Podfile` is auto-generated by Flutter tooling and is committed (standard practice for a CocoaPods-using Flutter project); `ios/Pods/` stays gitignored as the regenerable resolved-dependency output. Every other plugin in this project still integrates via SPM — CocoaPods is only in the mix because of this one dependency.

#### Edge Function: `supabase/functions/send-message-push`

Invoked by `ChatRemoteDataSourceImpl.sendMessage` right after a successful `messages` insert — best-effort; the message itself has already landed regardless of whether the push succeeds.

- Verifies the caller's JWT and that they are the message's own sender (prevents spoofing a push on someone else's behalf)
- Recipients = itinerary owner + members, minus the sender. The `members` JSONB array mixes key casing depending on which code path wrote the entry — `handle_new_user` uses `userId`, the Flutter client's invite flow uses `user_id` (see Stage 11/13) — so both `m.userId` and `m.user_id` must be checked, or client-invited members silently get no push
- Filtered by the recipient's `chat_messages` / `push` notification preference (default enabled) and, per-recipient, `push_message_preview_enabled` controls whether the body shows real message content or a generic "New message"
- FCM auth uses a service-account OAuth2 flow implemented with Deno's native Web Crypto (RS256-signed JWT bearer assertion) — no third-party JWT dependency
- Stale tokens (FCM `UNREGISTERED`/`NOT_FOUND`/`INVALID_ARGUMENT`) are deleted from `push_tokens` after a failed send

**Required secret (set once):**
```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT_KEY='{"type":"service_account",...}'
```

**Deploy:**
```bash
supabase functions deploy send-message-push
```

#### Token registration

`fcmTokenSyncProvider` (`lib/core/notifications/notification_providers.dart`) requests permission, fetches the FCM token, and keeps it registered via `upsert_push_token` for as long as the user is authenticated, re-registering on `FirebaseMessaging.instance.onTokenRefresh`. Runs for Android always; for iOS only once `kIosPushReady` is `true`.

#### Key design decisions

- **Data-only for Android, alert-only for iOS** is a deliberate platform split, not an inconsistency — see Architecture above.
- **No dependency on a notification-sending queue or cron.** Push is fired synchronously (fire-and-forget from the client's point of view) right after the message insert; a failure there never blocks or fails the send.
- **`push_tokens` is a public multi-row table per user** (a user can have several devices), never a single column on `profiles` — matches how `username_history`/`profile_change_log` were modeled as separate tables in Stage 16 rather than bolted onto `profiles`.

#### Platform config files are gitignored

`android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` were committed when the Firebase project was first wired up (Stage 19), which tripped secret scanning on the embedded per-app API key. They're now gitignored; `*.example` templates next to each (with placeholder values) document the required shape. To build locally, download the real files from Firebase console → Project settings → your app, and drop them in place — no build config changes needed since the paths are unchanged.

