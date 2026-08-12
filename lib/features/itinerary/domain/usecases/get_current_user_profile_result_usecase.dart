import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/profile_result.dart';
import '../repositories/profile_lookup_repository.dart';

/// Named `...ProfileResult...`, not `GetCurrentUserProfileUseCase`, to avoid
/// colliding in meaning with the `profile` feature's own, unrelated
/// `UserProfile` fetch — this returns the narrower [ProfileResult] shape.
class GetCurrentUserProfileResultUseCase {
  const GetCurrentUserProfileResultUseCase(this._repository);

  final ProfileLookupRepository _repository;

  Future<Either<Failure, ProfileResult?>> call() =>
      _repository.getCurrentUserProfile();
}
