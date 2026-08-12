import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/profile_result.dart';
import '../repositories/profile_lookup_repository.dart';

class FindProfileByEmailUseCase {
  const FindProfileByEmailUseCase(this._repository);

  final ProfileLookupRepository _repository;

  Future<Either<Failure, ProfileResult?>> call(String email) =>
      _repository.findByEmail(email);
}
