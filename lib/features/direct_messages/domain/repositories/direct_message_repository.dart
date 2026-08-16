import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../chat/domain/entities/message_read_receipt.dart';
import '../entities/direct_message.dart';
import '../entities/dm_conversation.dart';

abstract class DirectMessageRepository {
  Stream<Either<Failure, List<DmConversation>>> watchConversations();

  Stream<Either<Failure, List<DirectMessage>>> watchMessages(
    String conversationId,
  );

  Future<Either<Failure, List<DirectMessage>>> fetchMessagesBefore({
    required String conversationId,
    required DateTime before,
    int limit = 50,
  });

  Future<Either<Failure, void>> sendMessage({
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

  /// Finds the existing conversation between the caller and [otherUserId],
  /// or atomically creates one — see `get_or_create_dm_conversation` in
  /// `stage48_direct_messages.sql`. Fails if either side has blocked the
  /// other.
  Future<Either<Failure, String>> getOrCreateConversation(String otherUserId);

  Future<Either<Failure, void>> markMessagesRead(String conversationId);

  Future<Either<Failure, List<MessageReadReceipt>>> getReadReceipts(
    String messageId,
  );

  Future<Either<Failure, ({String storagePath, String publicUrl})>>
  uploadAttachment({
    required Uint8List bytes,
    required String userId,
    required String fileExtension,
    required String mimeType,
  });

  Future<Either<Failure, void>> blockUser(String userId);

  Future<Either<Failure, void>> unblockUser(String userId);

  /// Whether the caller has blocked [userId] — one-directional, see
  /// `blocked_users` in `stage48_direct_messages.sql`. Checked on opening a
  /// thread so the composer correctly stays disabled across app restarts,
  /// not just for the rest of the current session.
  Future<Either<Failure, bool>> isBlockedByMe(String userId);
}
