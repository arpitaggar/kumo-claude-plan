import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/organization_repository.dart';

class RemoveOrgMemberUseCase {
  const RemoveOrgMemberUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, void>> call(String orgMemberId) =>
      _repository.removeMember(orgMemberId);
}
