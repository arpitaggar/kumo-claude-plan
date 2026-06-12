import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/message.dart';

abstract class ChatRepository {
  Stream<Either<Failure, List<Message>>> watchMessages(String itineraryId);

  Future<Either<Failure, void>> sendMessage({
    required String itineraryId,
    required String senderId,
    required String senderName,
    required String content,
  });
}
