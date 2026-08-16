import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../chat/data/models/message_attachment_model.dart';
import '../../../chat/data/models/message_read_receipt_model.dart';
import '../models/direct_message_model.dart';
import '../models/dm_conversation_model.dart';

const _dmMessageCols = '*, message_attachments(*)';

abstract class DirectMessageRemoteDataSource {
  Stream<List<DmConversationModel>> watchConversations();
  Stream<List<DirectMessageModel>> watchMessages(String conversationId);
  Future<List<DirectMessageModel>> fetchMessagesBefore({
    required String conversationId,
    required DateTime before,
    int limit = 50,
  });
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String content,
    String? attachmentStoragePath,
    String? attachmentUrl,
    String? attachmentFileName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    String? attachmentKind,
  });
  Future<String> getOrCreateConversation(String otherUserId);
  Future<void> markMessagesRead(String conversationId);
  Future<List<MessageReadReceiptModel>> getReadReceipts(String messageId);
  Future<({String storagePath, String publicUrl})> uploadAttachment({
    required Uint8List bytes,
    required String userId,
    required String fileExtension,
    required String mimeType,
  });
  Future<void> blockUser(String userId);
  Future<void> unblockUser(String userId);
  Future<bool> isBlockedByMe(String userId);
}

class DirectMessageRemoteDataSourceImpl
    implements DirectMessageRemoteDataSource {
  const DirectMessageRemoteDataSourceImpl();

  static const _streamLimit = 100;

  @override
  Stream<List<DmConversationModel>> watchConversations() {
    final currentUserId = KumoSupabaseClient.currentUser?.id;
    if (currentUserId == null) {
      return Stream.value(const []);
    }
    return KumoSupabaseClient.client
        .from('dm_conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at')
        .asyncMap((rows) => _withProfiles(rows, currentUserId));
  }

  /// `.stream()` can't embed a join to `profiles`, so the "other
  /// participant"'s name/avatar are fetched in one batched extra query and
  /// merged in here — same two-query pattern
  /// `ChatRemoteDataSourceImpl._withAttachments` uses for message
  /// attachments.
  Future<List<DmConversationModel>> _withProfiles(
    List<Map<String, dynamic>> rows,
    String currentUserId,
  ) async {
    if (rows.isEmpty) {
      return const [];
    }

    final otherUserIds = rows
        .map((r) {
          final a = r['user_a'] as String;
          final b = r['user_b'] as String;
          return a == currentUserId ? b : a;
        })
        .toSet()
        .toList();

    var profilesById = <String, DmConversationProfileInfo>{};
    try {
      final profileRows = await KumoSupabaseClient.client
          .from('profiles')
          .select('id, display_name, avatar_url')
          .inFilter('id', otherUserIds);
      profilesById = {
        for (final row in profileRows as List)
          (row as Map<String, dynamic>)['id']
              as String: DmConversationProfileInfo(
            displayName: (row['display_name'] as String?) ?? '',
            avatarUrl: row['avatar_url'] as String?,
          ),
      };
    } on sb.PostgrestException {
      // Profile lookup failing shouldn't break the conversation list — each
      // row just falls back to an empty name/no avatar.
    }

    return rows
        .map(
          (r) => DmConversationModel.fromJson(
            r,
            currentUserId: currentUserId,
            profilesById: profilesById,
          ),
        )
        .toList();
  }

  @override
  Stream<List<DirectMessageModel>> watchMessages(String conversationId) =>
      KumoSupabaseClient.client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('dm_conversation_id', conversationId)
          .order('created_at')
          .limit(_streamLimit)
          .asyncMap((rows) async {
            final messages = rows.map(DirectMessageModel.fromJson).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return _withAttachments(messages);
          });

  Future<List<DirectMessageModel>> _withAttachments(
    List<DirectMessageModel> messages,
  ) async {
    if (messages.isEmpty) {
      return messages;
    }
    try {
      final ids = messages.map((m) => m.id).toList();
      final rows = await KumoSupabaseClient.client
          .from('message_attachments')
          .select()
          .inFilter('message_id', ids);

      final byMessageId = <String, List<MessageAttachmentModel>>{};
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final messageId = map['message_id'] as String;
        (byMessageId[messageId] ??= []).add(
          MessageAttachmentModel.fromJson(map),
        );
      }

      return [
        for (final m in messages)
          DirectMessageModel(
            id: m.id,
            dmConversationId: m.dmConversationId,
            senderId: m.senderId,
            senderName: m.senderName,
            content: m.content,
            createdAt: m.createdAt,
            readBy: m.readBy,
            attachments: byMessageId[m.id] ?? const [],
          ),
      ];
    } on sb.PostgrestException {
      return messages;
    }
  }

  @override
  Future<List<DirectMessageModel>> fetchMessagesBefore({
    required String conversationId,
    required DateTime before,
    int limit = 50,
  }) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from('messages')
          .select(_dmMessageCols)
          .eq('dm_conversation_id', conversationId)
          .lt('created_at', before.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => DirectMessageModel.fromJson(r as Map<String, dynamic>))
          .toList()
          .reversed
          .toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String content,
    String? attachmentStoragePath,
    String? attachmentUrl,
    String? attachmentFileName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    String? attachmentKind,
  }) async {
    try {
      final messageId = const Uuid().v4();
      await KumoSupabaseClient.client.from('messages').insert({
        'id': messageId,
        'dm_conversation_id': conversationId,
        'sender_id': senderId,
        'sender_name': senderName,
        'content': content,
      });

      if (attachmentUrl != null) {
        await KumoSupabaseClient.client.from('message_attachments').insert({
          'message_id': messageId,
          'storage_path': attachmentStoragePath,
          'public_url': attachmentUrl,
          'file_name': attachmentFileName,
          'mime_type': attachmentMimeType,
          'size_bytes': attachmentSizeBytes,
          'kind': attachmentKind,
        });
      }

      // Best-effort push dispatch — failure here does not fail the send.
      // send-message-push branches internally on itinerary_id vs
      // dm_conversation_id, no separate DM function needed.
      try {
        final res = await KumoSupabaseClient.client.functions.invoke(
          'send-message-push',
          body: {'message_id': messageId},
        );
        AppLogger.info(
          'send-message-push: status=${res.status} data=${res.data}',
        );
      } catch (e, st) {
        AppLogger.warning('send-message-push invoke failed: $e\n$st');
      }
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<String> getOrCreateConversation(String otherUserId) async {
    try {
      final result = await KumoSupabaseClient.client.rpc(
        'get_or_create_dm_conversation',
        params: {'p_other_user_id': otherUserId},
      );
      return result as String;
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> markMessagesRead(String conversationId) async {
    try {
      await KumoSupabaseClient.client.rpc(
        'mark_dm_messages_read',
        params: {'p_conversation_id': conversationId},
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<MessageReadReceiptModel>> getReadReceipts(
    String messageId,
  ) async {
    try {
      final rows = await KumoSupabaseClient.client.rpc(
        'get_message_read_receipts',
        params: {'p_message_id': messageId},
      );
      return (rows as List)
          .map(
            (r) => MessageReadReceiptModel.fromJson(r as Map<String, dynamic>),
          )
          .toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<({String storagePath, String publicUrl})> uploadAttachment({
    required Uint8List bytes,
    required String userId,
    required String fileExtension,
    required String mimeType,
  }) async {
    try {
      final storagePath = '$userId/${const Uuid().v4()}.$fileExtension';
      await KumoSupabaseClient.client.storage
          .from('chat-attachments')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: sb.FileOptions(contentType: mimeType),
          );
      final publicUrl = KumoSupabaseClient.client.storage
          .from('chat-attachments')
          .getPublicUrl(storagePath);
      return (storagePath: storagePath, publicUrl: publicUrl);
    } on sb.StorageException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> blockUser(String userId) async {
    try {
      await KumoSupabaseClient.client.rpc(
        'block_user',
        params: {'p_user_id': userId},
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> unblockUser(String userId) async {
    try {
      await KumoSupabaseClient.client.rpc(
        'unblock_user',
        params: {'p_user_id': userId},
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<bool> isBlockedByMe(String userId) async {
    final currentUserId = KumoSupabaseClient.currentUser?.id;
    if (currentUserId == null) {
      return false;
    }
    try {
      final rows = await KumoSupabaseClient.client
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', currentUserId)
          .eq('blocked_id', userId);
      return (rows as List).isNotEmpty;
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
