import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/hitchhiker.dart';
import '../repositories/hitchhiker_repository.dart';

class CreateHitchhikerUseCase {
  const CreateHitchhikerUseCase(this._repository);

  final HitchhikerRepository _repository;

  Future<Either<Failure, Hitchhiker>> call({
    required String itineraryId,
    required String displayName,
  }) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('Name is required'));
    }
    if (trimmed.length > 60) {
      return const Left(
        ValidationFailure('Name must be 60 characters or fewer'),
      );
    }
    return _repository.createHitchhiker(
      itineraryId: itineraryId,
      displayName: trimmed,
    );
  }
}
