import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/hitchhiker_access_repository.dart';

class SendHitchhikerMessageUseCase {
  const SendHitchhikerMessageUseCase(this._repository);

  final HitchhikerAccessRepository _repository;

  Future<Either<Failure, void>> call({
    required String token,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('Message cannot be empty'));
    }
    if (trimmed.length > 4000) {
      return const Left(ValidationFailure('Message is too long'));
    }
    return _repository.sendMessage(token: token, content: trimmed);
  }
}
