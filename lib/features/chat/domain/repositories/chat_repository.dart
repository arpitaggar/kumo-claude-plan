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
}
