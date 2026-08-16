import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/notifications/push_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/domain/entities/message_read_receipt.dart';
import '../../../profile/domain/entities/notification_preference.dart';
import '../../../profile/presentation/providers/user_profile_provider.dart';
import '../../data/datasources/direct_message_remote_datasource.dart';
import '../../data/repositories/direct_message_repository_impl.dart';
import '../../domain/entities/direct_message.dart';
import '../../domain/entities/dm_conversation.dart';
import '../../domain/repositories/direct_message_repository.dart';
import '../../domain/usecases/send_direct_message_usecase.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

final directMessageRemoteDataSourceProvider =
    Provider<DirectMessageRemoteDataSource>(
      (_) => const DirectMessageRemoteDataSourceImpl(),
    );

final directMessageRepositoryProvider = Provider<DirectMessageRepository>(
  (ref) => DirectMessageRepositoryImpl(
    remoteDataSource: ref.watch(directMessageRemoteDataSourceProvider),
  ),
);

final sendDirectMessageUseCaseProvider = Provider<SendDirectMessageUseCase>(
  (ref) => SendDirectMessageUseCase(ref.watch(directMessageRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Conversation list — powers the Inbox "Direct" tab and the unread badge.
// Denormalized (dm_conversations.last_message_at/_preview/_sender_id,
// maintained by touch_dm_conversation() — see stage48_direct_messages.sql),
// so this is one stream covering every conversation rather than the
// N-per-trip-stream approach chatStreamProvider uses.
// ---------------------------------------------------------------------------

final dmConversationListProvider = StreamProvider<List<DmConversation>>(
  (ref) => ref
      .watch(directMessageRepositoryProvider)
      .watchConversations()
      .map(
        (either) => either.fold(
          (failure) => throw Exception(failure.message),
          (conversations) => conversations,
        ),
      ),
);

// ---------------------------------------------------------------------------
// Stream provider — live message list for one conversation (last 100)
// ---------------------------------------------------------------------------

final dmMessageStreamProvider =
    StreamProvider.family<List<DirectMessage>, String>(
      (ref, conversationId) => ref
          .watch(directMessageRepositoryProvider)
          .watchMessages(conversationId)
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

final dmReadReceiptsProvider =
    FutureProvider.family<List<MessageReadReceipt>, String>((
      ref,
      messageId,
    ) async {
      final result = await ref
          .watch(directMessageRepositoryProvider)
          .getReadReceipts(messageId);
      return result.fold(
        (failure) => throw Exception(failure.message),
        (receipts) => receipts,
      );
    });

/// Whether the caller has blocked the other participant — checked when a
/// thread opens so the composer correctly stays disabled across app
/// restarts, not just for the rest of the session it was blocked in.
final dmIsBlockedByMeProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, otherUserId) async {
    final result = await ref
        .watch(directMessageRepositoryProvider)
        .isBlockedByMe(otherUserId);
    return result.fold((failure) => throw Exception(failure.message), (v) => v);
  },
);

// ---------------------------------------------------------------------------
// In-app new-message notifications — foreground/backgrounded-but-alive only,
// mirroring chatMessageWatcherProvider in
// lib/features/chat/presentation/providers/chat_provider.dart. Backgrounded/
// killed delivery goes through real OS push instead (`send-message-push`'s
// dm branch → push_message_handler.dart).
// ---------------------------------------------------------------------------

/// The conversation id currently on screen, if any. Set/cleared by
/// DmThreadPage so the watcher below doesn't notify about a thread the user
/// is already looking at.
final activeDmConversationIdProvider = StateProvider<String?>((_) => null);

/// Watches the single conversation-list stream (kept alive once mounted in
/// `KumoShell`, same lifetime as `chatMessageWatcherProvider`) and fires a
/// local notification when a conversation's denormalized `lastMessageAt`
/// advances due to a message from someone else.
final dmMessageWatcherProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<DmConversation>>>(dmConversationListProvider, (
    prev,
    next,
  ) {
    // Only a data→data transition is a genuinely new message; the initial
    // loading→data transition is just existing conversation history loading.
    if (prev is! AsyncData<List<DmConversation>> ||
        next is! AsyncData<List<DmConversation>>) {
      return;
    }
    final prevById = {for (final c in prev.value) c.id: c};
    for (final convo in next.value) {
      final lastAt = convo.lastMessageAt;
      if (lastAt == null) {
        continue;
      }
      final prevLastAt = prevById[convo.id]?.lastMessageAt;
      if (prevLastAt != null && !lastAt.isAfter(prevLastAt)) {
        continue;
      }
      _maybeNotify(ref, convo);
    }
  });
});

void _maybeNotify(Ref ref, DmConversation convo) {
  final authState = ref.read(authNotifierProvider);
  final currentUserId = authState is AuthAuthenticated
      ? authState.user.id
      : null;
  if (currentUserId == null || convo.lastMessageSenderId == currentUserId) {
    return;
  }
  if (ref.read(activeDmConversationIdProvider) == convo.id) {
    return;
  }
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;
  final isIosPushLive =
      defaultTargetPlatform == TargetPlatform.iOS && kIosPushReady;
  if ((isAndroid || isIosPushLive) &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    return;
  }

  // Reuses the chat_messages preference category rather than a separate
  // dm_messages one — v1 scope decision, see
  // lib/features/direct_messages/CLAUDE.md.
  final prefs = ref.read(notificationPreferencesProvider).value ?? const [];
  NotificationPreference? chatPref;
  for (final p in prefs) {
    if (p.channel == NotifChannel.push &&
        p.category == NotifCategory.chatMessages) {
      chatPref = p;
      break;
    }
  }
  if (chatPref?.enabled == false) {
    return;
  }

  final showPreview =
      ref.read(userProfileProvider).value?.pushMessagePreviewEnabled ?? true;
  final preview = convo.lastMessagePreview;
  final body = !showPreview
      ? 'New message'
      : (preview?.isNotEmpty == true ? preview! : 'New message');

  ref
      .read(notificationServiceProvider)
      .value
      ?.showDmMessageNotification(
        conversationId: convo.id,
        senderName: convo.otherUserName,
        body: body,
      );
}
