import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/profile_result.dart';
import '../repositories/profile_lookup_repository.dart';

class SearchProfilesByNameUseCase {
  const SearchProfilesByNameUseCase(this._repository);

  final ProfileLookupRepository _repository;

  Future<Either<Failure, List<ProfileResult>>> call(
    String query, {
    List<String> excludeIds = const [],
  }) => _repository.searchByName(query, excludeIds: excludeIds);
}
