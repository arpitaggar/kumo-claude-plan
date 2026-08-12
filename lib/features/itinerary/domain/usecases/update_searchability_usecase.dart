import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/profile_lookup_repository.dart';

class UpdateSearchabilityUseCase {
  const UpdateSearchabilityUseCase(this._repository);

  final ProfileLookupRepository _repository;

  Future<Either<Failure, void>> call({required bool isSearchable}) =>
      _repository.updateSearchability(isSearchable: isSearchable);
}
