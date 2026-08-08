import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/org_member.dart';
import '../repositories/organization_repository.dart';

class FetchOrgMembersUseCase {
  const FetchOrgMembersUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, List<OrgMember>>> call(String orgId) =>
      _repository.fetchOrgMembers(orgId);
}
