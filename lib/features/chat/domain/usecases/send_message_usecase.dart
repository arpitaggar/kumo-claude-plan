import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../repositories/chat_repository.dart';

class SendMessageUseCase {
  const SendMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<Either<Failure, void>> call({
    required String itineraryId,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('Message cannot be empty'));
    }
    if (trimmed.length > 4000) {
      return const Left(ValidationFailure('Message is too long'));
    }

    try {
      return _repository.sendMessage(
        itineraryId: itineraryId,
        senderId: senderId,
        senderName: senderName,
        content: trimmed,
      );
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    }
  }
}
