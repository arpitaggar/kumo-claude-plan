import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/org_member.dart';
import '../repositories/organization_repository.dart';

class InviteOrgMemberUseCase {
  const InviteOrgMemberUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, OrgMember>> call({
    required String orgId,
    required String email,
    required OrgMemberRole role,
  }) => _repository.inviteMember(orgId: orgId, email: email, role: role);
}
