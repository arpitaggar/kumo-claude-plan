import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/logger.dart';
import '../models/message_attachment_model.dart';
import '../models/message_model.dart';
import '../models/message_read_receipt_model.dart';

const _messageCols = '*, message_attachments(*)';

abstract class ChatRemoteDataSource {
  Stream<List<MessageModel>> watchMessages(String itineraryId);
  Future<List<MessageModel>> fetchMessagesBefore({
    required String itineraryId,
    required DateTime before,
    int limit = 50,
  });
  Future<void> sendMessage({
    required String itineraryId,
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
  Future<void> markMessagesRead(String itineraryId);
  Future<List<MessageReadReceiptModel>> getReadReceipts(String messageId);
  Future<void> upsertPushToken({required String token, required String platform});
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  const ChatRemoteDataSourceImpl();

  static const _streamLimit = 100;

  @override
  Stream<List<MessageModel>> watchMessages(String itineraryId) =>
      KumoSupabaseClient.client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('itinerary_id', itineraryId)
          .order('created_at')
          .limit(_streamLimit)
          .asyncMap((rows) async {
            // `.order()` reliably sorts the initial snapshot, but rows
            // re-emitted after a realtime INSERT aren't guaranteed to stay
            // sorted — sort explicitly so consumers (chat display, unread
            // badge, notification watcher) can always trust ascending order.
            final messages = rows.map(MessageModel.fromJson).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return _withAttachments(messages);
          });

  /// `.stream()` only selects base-table columns (no embedded joins), so
  /// attachments for the live feed are fetched in one extra query per
  /// snapshot and merged in here. `fetchMessagesBefore` below uses a normal
  /// (non-stream) query and can embed `message_attachments(*)` directly.
  Future<List<MessageModel>> _withAttachments(
    List<MessageModel> messages,
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
          MessageModel(
            id: m.id,
            itineraryId: m.itineraryId,
            senderId: m.senderId,
            senderName: m.senderName,
            content: m.content,
            createdAt: m.createdAt,
            readBy: m.readBy,
            attachments: byMessageId[m.id] ?? const [],
          ),
      ];
    } on sb.PostgrestException {
      // Attachment lookup failing shouldn't break the live message feed.
      return messages;
    }
  }

  @override
  Future<List<MessageModel>> fetchMessagesBefore({
    required String itineraryId,
    required DateTime before,
    int limit = 50,
  }) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from('messages')
          .select(_messageCols)
          .eq('itinerary_id', itineraryId)
          .lt('created_at', before.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);
      final models = (rows as List)
          .map((r) => MessageModel.fromJson(r as Map<String, dynamic>))
          .toList()
          .reversed
          .toList();
      return models;
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> sendMessage({
    required String itineraryId,
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
        'itinerary_id': itineraryId,
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
      try {
        final res = await KumoSupabaseClient.client.functions.invoke(
          'send-message-push',
          body: {'message_id': messageId},
        );
        AppLogger.info(
            'send-message-push: status=${res.status} data=${res.data}');
      } catch (e, st) {
        // Edge function not deployed, or the caller is offline — the
        // message itself already landed via the insert above.
        AppLogger.warning('send-message-push invoke failed: $e\n$st');
      }
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> markMessagesRead(String itineraryId) async {
    try {
      await KumoSupabaseClient.client.rpc(
        'mark_messages_read',
        params: {'p_itinerary_id': itineraryId},
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
          .map((r) =>
              MessageReadReceiptModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> upsertPushToken({
    required String token,
    required String platform,
  }) async {
    try {
      await KumoSupabaseClient.client.rpc(
        'upsert_push_token',
        params: {'p_token': token, 'p_platform': platform},
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
