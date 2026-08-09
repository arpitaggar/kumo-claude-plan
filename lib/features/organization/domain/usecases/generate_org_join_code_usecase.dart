import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/org_join_code.dart';
import '../entities/org_member.dart';
import '../repositories/organization_repository.dart';

class GenerateOrgJoinCodeUseCase {
  const GenerateOrgJoinCodeUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, OrgJoinCode>> call({
    required String orgId,
    required OrgMemberRole role,
    String? costFieldOptionId,
    DateTime? expiresAt,
    int? maxUses,
  }) => _repository.generateJoinCode(
    orgId: orgId,
    costFieldOptionId: costFieldOptionId,
    role: role,
    expiresAt: expiresAt,
    maxUses: maxUses,
  );
}
