import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/org_member.dart';
import '../repositories/organization_repository.dart';

class UpdateOrgMemberRoleUseCase {
  const UpdateOrgMemberRoleUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, void>> call({
    required String orgMemberId,
    required OrgMemberRole role,
  }) => _repository.updateMemberRole(orgMemberId: orgMemberId, role: role);
}
