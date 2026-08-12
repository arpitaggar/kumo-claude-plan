import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/message.dart';
import '../entities/message_read_receipt.dart';

abstract class ChatRepository {
  Stream<Either<Failure, List<Message>>> watchMessages(String itineraryId);

  Future<Either<Failure, List<Message>>> fetchMessagesBefore({
    required String itineraryId,
    required DateTime before,
    int limit = 50,
  });

  Future<Either<Failure, void>> sendMessage({
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

  Future<Either<Failure, List<MessageReadReceipt>>> getReadReceipts(
    String messageId,
  );

  /// Uploads chat-attachment bytes and returns the storage path (persisted
  /// alongside the message row) and its public URL.
  Future<Either<Failure, ({String storagePath, String publicUrl})>>
  uploadAttachment({
    required Uint8List bytes,
    required String userId,
    required String fileExtension,
    required String mimeType,
  });
}
