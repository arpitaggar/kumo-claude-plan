# lib/features/direct_messages

New 2026-08-16 — loads only when working under `lib/features/direct_messages/`. Private (1:1) messaging, independent of any shared trip.

### Why a parallel feature instead of widening `ChatRepository`

`Message.itineraryId` is non-nullable and baked into `MessageModel`, `_MessageBubble`'s consecutive-message grouping, every `ChatRepository` method signature, and ~8 existing test files. Rather than risk that surface, this feature is a structural clone — own entities (`DirectMessage`, `DmConversation`), own repository/datasource/providers/page — that shares the underlying `messages` table and reuses whatever was already itinerary-agnostic:

- `MessageAttachment`/`MessageReadReceipt` (`lib/features/chat/domain/entities/`) are imported directly, not duplicated — both are keyed only by `message_id`, with no reference to `itinerary_id` anywhere in their shape.
- `message_attachments`, the `chat-attachments` storage bucket, and `push_tokens` needed only an added RLS branch, not a rewrite.
- `get_message_read_receipts(p_message_id)` is reused with zero SQL change — already generic.

`dm_thread_page.dart` duplicates `chat_page.dart`'s presentational widgets (`_DateDivider`, `_TypingIndicator`, `_InputBar`, attachment bubbles, etc.) rather than importing them — they're `_private` to that file's library and Dart privacy is per-file, so sharing them would mean making them public first. Given how small each of them is, duplication was judged cheaper than the coupling that would introduce.

### Database (`docs/supabase_migrations/stage48_direct_messages.sql`)

Mirrors stage45_hitchhikers.sql's `sender_id`/`hitchhiker_id` XOR pattern: `messages.itinerary_id` became nullable, a new `dm_conversation_id` column was added, and a `messages_itinerary_xor_dm` check constraint guarantees exactly one of the two is ever set. The existing `messages_owner_all`/`messages_member_read`/`messages_member_insert` policies all key off `itinerary_id` inside an `exists (... where i.id = itinerary_id ...)` — a DM row (null `itinerary_id`) structurally can't match any of them, so those were left untouched; new sibling `messages_dm_participant_read`/`_insert` policies (OR'd, RLS is permissive) cover the DM case instead.

`public.dm_conversations` is the "who is this thread between" table — canonically ordered (`user_a = least(x,y)`, `user_b = greatest(x,y)`) so a unique index prevents a duplicate thread regardless of who starts it, with no client write policy at all (every row comes from `get_or_create_dm_conversation()`, SECURITY DEFINER, or the `touch_dm_conversation()` trigger). `last_message_at`/`_preview`/`_sender_id` are denormalized by that trigger specifically so the DM inbox can stream this one table directly, ordered by `last_message_at`, instead of watching every conversation's message stream individually the way `chatStreamProvider`'s per-trip fan-out works — a deliberate asymmetry with group chat's own inbox mechanism, not an inconsistency to "fix."

`public.blocked_users` shipped in the same migration, not as a follow-up — DMs make "a stranger found via search messages you unsolicited" possible for the first time in this app, and there was no block mechanism anywhere before this. A block (either direction) is enforced at the RLS/RPC layer (`get_or_create_dm_conversation` and `messages_dm_participant_insert` both check it), not just hidden in the UI — `DmThreadPage`'s composer-disable is a convenience, the database is the actual boundary.

### Flutter layer

- **Entities:** `domain/entities/direct_message.dart`, `dm_conversation.dart`.
- **Repository:** `domain/repositories/direct_message_repository.dart` — mirrors `ChatRepository`'s shape (`watchMessages`, `fetchMessagesBefore`, `sendMessage`, `getReadReceipts`, `uploadAttachment`) plus DM-only operations (`watchConversations`, `getOrCreateConversation`, `markMessagesRead`, `blockUser`/`unblockUser`/`isBlockedByMe`).
- **Data layer:** `data/datasources/direct_message_remote_datasource.dart` — same `.stream()` + batched-second-query pattern `ChatRemoteDataSourceImpl` uses for attachments, applied twice here (once for message attachments, once for `dm_conversations`' other-participant profile lookup, since `.stream()` can't embed joins). `data/repositories/direct_message_repository_impl.dart` replicates `ChatRepositoryImpl`'s corrected `StreamTransformer`-based error mapping (`Stream.handleError`'s callback return value is silently discarded — a past real bug in chat's own repository, see its own file comment).
- **Providers:** `presentation/providers/direct_message_provider.dart` — `dmConversationListProvider` (one stream, powers both the inbox and the unread badge), `dmMessageStreamProvider` (family, per conversation), `activeDmConversationIdProvider`/`dmMessageWatcherProvider` (foreground notification watcher, mirrors `chatMessageWatcherProvider` but watches the single conversation-list stream instead of a per-trip fan-out — see the denormalization note above), `dmIsBlockedByMeProvider` (checked on opening a thread so the composer correctly stays disabled across app restarts, not just for the rest of the session it was blocked in).
- **UI:** `presentation/pages/dm_thread_page.dart` (route `/dm/:conversationId`) — near-clone of `ChatPage`, typing channel namespaced `typing:dm:$conversationId` (vs. chat's `typing:$itineraryId`) to keep the two Realtime broadcast channels structurally distinct, and replicates the 2026-08-15 `RealtimeChannel.subscribe()` hardening (`_typingSubscribeAttempted` guard + try/catch + crash-report) since that fix wasn't chat-specific — it's a real double-subscribe hazard in the underlying package. Overflow menu has "Block/Unblock `<name>`"; a blocked thread's composer is replaced with a banner + Unblock button rather than just disabling the `TextField` in place.

### Entry points

- **Member-row long-press** (`itinerary_detail_page.dart`'s `_MemberRow`) — replaced the old tap-triggered three-dot `PopupMenuButton` entirely with a long-press bottom sheet (`_MemberActionsSheet`) offering "Message privately" (everyone, except your own row) plus "Change role"/"Remove from trip" (owners only) — the latter two call the **existing, unmodified** `_MembersCard._changeRole`/`_removeMember`, not reimplemented.
- **Search/invite flow** (`invite_member_page.dart`) — `_ProfileTile` (Search tab) and `_ProfileCard` (Email tab) both gained a "Message" icon button alongside "Add to trip". `_ProfileCard` only ever renders for a real found account (`ProfileResult` with a real user id) — the pending/email-only-no-account path (`_PendingBanner`) never renders it, so there's no explicit exclusion needed, it falls out of the existing branch structure.
- **Inbox** (`lib/features/shell/inbox_page.dart`) — extended with a Trips/Direct `TabBar` rather than adding a separate DM inbox screen or a 6th bottom-nav icon; discovered mid-implementation that an Inbox tab already existed (trips-only), which changed the original plan's assumption. `inboxHasUnreadProvider` (`lib/features/chat/presentation/providers/chat_provider.dart`) was extended in place to also scan `dmConversationListProvider` — kept in the `chat` feature folder for now rather than relocated, a small deliberate cross-feature-import trade-off.

### Push notifications

`supabase/functions/send-message-push/index.ts` branches once, right after loading the message row, on `itinerary_id` vs. `dm_conversation_id` — only the recipient-resolution step differs (a trip-members scan vs. a single `dm_conversations` lookup for the other participant); the FCM-send/OAuth2/stale-token machinery is fully shared. Reuses the existing `chat_messages` notification-preference category rather than adding a separate `dm_messages` one — v1 scope decision, revisit if users actually want independent control. Client dispatch (`lib/core/notifications/push_message_handler.dart`, `notification_service.dart`) follows the existing `kind`-based branching this codebase already used for `'social'` vs `'chat'` — added `'dm'` alongside them, plus a `dm_messages` Android notification channel.

### Known v1 limitations (not gaps — explicit scope cuts)

- No read receipts/typing-indicator parity polish beyond what's listed above — DMs get the same typing indicator and read-receipt info sheet chat has, nothing less, nothing extra.
- Blocking is minimal: one-directional, private (the blocked party is never told), no report/appeal flow, no blocked-users management page — `block_user`/`unblock_user` RPCs exist but there's no UI to browse your own block list outside the thread you blocked someone from.
- No independent DM push-notification category — see above.
- DM permission model is "anyone can DM anyone" (mirrors how trip co-members can already message each other freely) — not gated by `follows` or any other relationship graph.
