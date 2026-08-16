import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/notifications/push_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../direct_messages/presentation/providers/direct_message_provider.dart';
import '../../../itinerary/presentation/providers/itinerary_provider.dart';
import '../../../profile/domain/entities/notification_preference.dart';
import '../../../profile/presentation/providers/user_profile_provider.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_attachment.dart';
import '../../domain/entities/message_read_receipt.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/send_message_usecase.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>(
  (_) => const ChatRemoteDataSourceImpl(),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepositoryImpl(
    remoteDataSource: ref.watch(chatRemoteDataSourceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Use-case providers
// ---------------------------------------------------------------------------

final sendMessageUseCaseProvider = Provider<SendMessageUseCase>(
  (ref) => SendMessageUseCase(ref.watch(chatRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Stream provider — live message list for one itinerary (last 100)
// ---------------------------------------------------------------------------

final chatStreamProvider = StreamProvider.family<List<Message>, String>(
  (ref, itineraryId) => ref
      .watch(chatRepositoryProvider)
      .watchMessages(itineraryId)
      .map(
        (either) => either.fold(
          (failure) => throw Exception(failure.message),
          (messages) => messages,
        ),
      ),
);

// ---------------------------------------------------------------------------
// Read-receipt detail — fetched on demand when a sent message is long-pressed
// ---------------------------------------------------------------------------

final messageReadReceiptsProvider =
    FutureProvider.family<List<MessageReadReceipt>, String>((
      ref,
      messageId,
    ) async {
      final result = await ref
          .watch(chatRepositoryProvider)
          .getReadReceipts(messageId);
      return result.fold(
        (failure) => throw Exception(failure.message),
        (receipts) => receipts,
      );
    });

// ---------------------------------------------------------------------------
// Inbox badge — tracks last visit time and whether there are unread messages
// ---------------------------------------------------------------------------

/// Epoch-ms timestamp of the last time the user opened the Inbox tab.
/// Initialised to 0; InboxPage updates it from SharedPreferences on mount.
final inboxLastVisitProvider = StateProvider<int>((_) => 0);

/// True when any trip or DM conversation has a message newer than
/// [inboxLastVisitProvider] — the badge is tab-level (Trips + Direct
/// combined), not sub-tab-level, matching how a single Inbox visit already
/// clears it for every trip regardless of which trip's chat was actually
/// read.
final inboxHasUnreadProvider = Provider<bool>((ref) {
  final lastVisitMs = ref.watch(inboxLastVisitProvider);
  if (lastVisitMs == 0) {
    return false;
  }

  final listState = ref.watch(itineraryListProvider);
  if (listState is ItineraryListLoaded) {
    for (final trip in listState.itineraries) {
      final msgs = ref.watch(chatStreamProvider(trip.id));
      final latest = msgs.value?.isNotEmpty == true ? msgs.value!.last : null;
      if (latest != null &&
          latest.createdAt.millisecondsSinceEpoch > lastVisitMs) {
        return true;
      }
    }
  }

  final authState = ref.watch(authNotifierProvider);
  final currentUserId = authState is AuthAuthenticated
      ? authState.user.id
      : null;
  final conversations = ref.watch(dmConversationListProvider).value ?? const [];
  for (final convo in conversations) {
    final lastAt = convo.lastMessageAt;
    if (lastAt == null || convo.lastMessageSenderId == currentUserId) {
      continue;
    }
    if (lastAt.millisecondsSinceEpoch > lastVisitMs) {
      return true;
    }
  }
  return false;
});

// ---------------------------------------------------------------------------
// In-app new-message notifications.
//
// Android: this watcher only fires while the app is actually foregrounded;
// backgrounded/killed delivery goes through real OS push instead (FCM data
// message → `push_message_handler.dart`, sent server-side by
// `supabase/functions/send-message-push`).
//
// iOS: no background push wired yet (needs an APNs key uploaded in Firebase),
// so this remains the only delivery mechanism there — best-effort,
// foreground/backgrounded-but-alive only.
// ---------------------------------------------------------------------------

/// The itinerary id of the chat currently on screen, if any. Set/cleared by
/// ChatPage so the watcher below doesn't notify about a chat the user is
/// already looking at.
final activeChatIdProvider = StateProvider<String?>((_) => null);

/// Watches every trip's chat stream for the lifetime it's kept alive (mounted
/// once in `KumoShell`, which stays alive for the whole authenticated
/// session) and fires a local notification for new messages from other
/// people, subject to the user's notification preferences.
final chatMessageWatcherProvider = Provider<void>((ref) {
  final listState = ref.watch(itineraryListProvider);
  if (listState is! ItineraryListLoaded) {
    return;
  }

  for (final trip in listState.itineraries) {
    ref.listen<AsyncValue<List<Message>>>(chatStreamProvider(trip.id), (
      prev,
      next,
    ) {
      // Only a data→data transition is a genuinely new message; the initial
      // loading→data transition is just the existing history downloading.
      if (prev is! AsyncData<List<Message>> ||
          next is! AsyncData<List<Message>>) {
        return;
      }
      if (next.value.isEmpty) {
        return;
      }
      final latest = next.value.last;
      final prevLatestId = prev.value.isNotEmpty ? prev.value.last.id : null;
      if (latest.id == prevLatestId) {
        return;
      }
      _maybeNotify(
        ref,
        tripId: trip.id,
        tripTitle: trip.title,
        message: latest,
      );
    });
  }
});

void _maybeNotify(
  Ref ref, {
  required String tripId,
  required String tripTitle,
  required Message message,
}) {
  final authState = ref.read(authNotifierProvider);
  final currentUserId = authState is AuthAuthenticated
      ? authState.user.id
      : null;
  if (currentUserId == null || message.senderId == currentUserId) {
    return;
  }
  if (ref.read(activeChatIdProvider) == tripId) {
    return;
  }
  // Once real OS push is live for a platform (Android always; iOS once
  // kIosPushReady flips on), it owns non-foreground delivery — showing a
  // local notification here too would double up. Until then (iOS today),
  // this best-effort in-process watcher is the only delivery mechanism, so
  // it keeps firing regardless of lifecycle state.
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;
  final isIosPushLive =
      defaultTargetPlatform == TargetPlatform.iOS && kIosPushReady;
  if ((isAndroid || isIosPushLive) &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    return;
  }

  final prefs = ref.read(notificationPreferencesProvider).value ?? const [];
  NotificationPreference? chatPref;
  for (final p in prefs) {
    if (p.channel == NotifChannel.push &&
        p.category == NotifCategory.chatMessages) {
      chatPref = p;
      break;
    }
  }
  // Default to enabled if prefs haven't loaded yet or no row exists — matches
  // the DB's own default (seed_notification_preferences seeds this true).
  if (chatPref?.enabled == false) {
    return;
  }

  final showPreview =
      ref.read(userProfileProvider).value?.pushMessagePreviewEnabled ?? true;
  final body = !showPreview
      ? 'New message'
      : message.content.isNotEmpty
      ? message.content
      : message.attachments.isNotEmpty &&
            message.attachments.first.kind == AttachmentKind.image
      ? '📷 Photo'
      : '📎 Attachment';

  ref
      .read(notificationServiceProvider)
      .value
      ?.showChatMessageNotification(
        tripId: tripId,
        tripTitle: tripTitle,
        senderName: message.senderName,
        body: body,
      );
}
