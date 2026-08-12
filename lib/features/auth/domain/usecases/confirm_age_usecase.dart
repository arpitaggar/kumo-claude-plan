import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/auth_repository.dart';

class ConfirmAgeUseCase {
  const ConfirmAgeUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, bool>> call(DateTime dateOfBirth) =>
      _repository.confirmAge(dateOfBirth);
}
