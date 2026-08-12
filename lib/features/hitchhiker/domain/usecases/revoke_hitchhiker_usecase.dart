import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/hitchhiker_repository.dart';

class RevokeHitchhikerUseCase {
  const RevokeHitchhikerUseCase(this._repository);

  final HitchhikerRepository _repository;

  Future<Either<Failure, void>> call(String hitchhikerId) =>
      _repository.revokeHitchhiker(hitchhikerId);
}
