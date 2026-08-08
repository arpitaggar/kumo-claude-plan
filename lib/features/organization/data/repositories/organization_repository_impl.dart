import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/org_cost_field.dart';
import '../../domain/entities/org_cost_field_option.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/organization.dart';
import '../../domain/entities/pending_expense_approval.dart';
import '../../domain/repositories/organization_repository.dart';
import '../datasources/organization_remote_datasource.dart';

class OrganizationRepositoryImpl implements OrganizationRepository {
  const OrganizationRepositoryImpl({required this.dataSource});

  final OrganizationRemoteDataSource dataSource;

  @override
  Future<Either<Failure, Organization>> createOrganization({
    required String name,
    required String slug,
  }) async {
    try {
      final org = await dataSource.createOrganization(name: name, slug: slug);
      return Right(org);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Organization>>> fetchMyOrganizations() async {
    try {
      final orgs = await dataSource.fetchMyOrganizations();
      return Right(orgs);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<OrgMember>>> fetchOrgMembers(
    String orgId,
  ) async {
    try {
      final members = await dataSource.fetchOrgMembers(orgId);
      return Right(members);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OrgMember>> inviteMember({
    required String orgId,
    required String email,
    required OrgMemberRole role,
  }) async {
    try {
      final member = await dataSource.inviteMember(
        orgId: orgId,
        email: email,
        role: role,
      );
      return Right(member);
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateMemberRole({
    required String orgMemberId,
    required OrgMemberRole role,
  }) async {
    try {
      await dataSource.updateMemberRole(orgMemberId: orgMemberId, role: role);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeMember(String orgMemberId) async {
    try {
      await dataSource.removeMember(orgMemberId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PendingExpenseApproval>>> fetchPendingApprovals(
    String orgId,
  ) async {
    try {
      final approvals = await dataSource.fetchPendingApprovals(orgId);
      return Right(approvals);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> approveExpense(String expenseId) async {
    try {
      await dataSource.approveExpense(expenseId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> rejectExpense(
    String expenseId,
    String reason,
  ) async {
    try {
      await dataSource.rejectExpense(expenseId, reason);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<OrgCostField>>> fetchOrgCostFields(
    String orgId,
  ) async {
    try {
      final fields = await dataSource.fetchOrgCostFields(orgId);
      return Right(fields);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OrgCostField>> createCostField({
    required String orgId,
    required String label,
    required CostFieldType fieldType,
    String separator = '-',
    List<String> sourceFieldIds = const [],
  }) async {
    try {
      final field = await dataSource.createCostField(
        orgId: orgId,
        label: label,
        fieldType: fieldType,
        separator: separator,
        sourceFieldIds: sourceFieldIds,
      );
      return Right(field);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCostField(String fieldId) async {
    try {
      await dataSource.deleteCostField(fieldId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OrgCostFieldOption>> addCostFieldOption({
    required String fieldId,
    required String value,
    required String code,
  }) async {
    try {
      final option = await dataSource.addCostFieldOption(
        fieldId: fieldId,
        value: value,
        code: code,
      );
      return Right(option);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCostFieldOption(String optionId) async {
    try {
      await dataSource.deleteCostFieldOption(optionId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String?>> previewCostCenterCode({
    required String orgId,
    required Map<String, String> selections,
  }) async {
    try {
      final code = await dataSource.previewCostCenterCode(
        orgId: orgId,
        selections: selections,
      );
      return Right(code);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
