import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/org_cost_field.dart';
import '../entities/org_cost_field_option.dart';
import '../entities/org_member.dart';
import '../entities/organization.dart';
import '../entities/pending_expense_approval.dart';

abstract class OrganizationRepository {
  Future<Either<Failure, Organization>> createOrganization({
    required String name,
    required String slug,
  });

  /// Organizations the current user belongs to (owner or member).
  Future<Either<Failure, List<Organization>>> fetchMyOrganizations();

  Future<Either<Failure, List<OrgMember>>> fetchOrgMembers(String orgId);

  /// Adds an existing Kumo user (looked up by email) to the org. Returns a
  /// [NotFoundFailure] if no account exists for that email yet — inviting
  /// someone without a Kumo account is out of scope for this version (see
  /// stage28's migration comment on scope).
  Future<Either<Failure, OrgMember>> inviteMember({
    required String orgId,
    required String email,
    required OrgMemberRole role,
  });

  Future<Either<Failure, void>> updateMemberRole({
    required String orgMemberId,
    required OrgMemberRole role,
  });

  Future<Either<Failure, void>> removeMember(String orgMemberId);

  /// All expenses currently awaiting this org's review, across every
  /// org-tagged trip.
  Future<Either<Failure, List<PendingExpenseApproval>>> fetchPendingApprovals(
    String orgId,
  );

  Future<Either<Failure, void>> approveExpense(String expenseId);

  Future<Either<Failure, void>> rejectExpense(
    String expenseId,
    String reason,
  );

  /// An org's full cost-tracking structure — every field with its options
  /// (for `select` fields) or source field ids (for the `generated` field),
  /// see stage30's migration.
  Future<Either<Failure, List<OrgCostField>>> fetchOrgCostFields(String orgId);

  /// Creates a `select` field (pass no [sourceFieldIds]) or the org's one
  /// `generated` field (pass the ordered fields it draws from).
  Future<Either<Failure, OrgCostField>> createCostField({
    required String orgId,
    required String label,
    required CostFieldType fieldType,
    String separator,
    List<String> sourceFieldIds,
  });

  /// Fails with a friendly [ServerFailure] if the field is still referenced
  /// by an existing trip's assignment or a generated field's sources (DB
  /// foreign-key restrict, see stage30).
  Future<Either<Failure, void>> deleteCostField(String fieldId);

  Future<Either<Failure, OrgCostFieldOption>> addCostFieldOption({
    required String fieldId,
    required String value,
    required String code,
  });

  /// Fails with a friendly [ServerFailure] if the option is still assigned
  /// to an existing trip.
  Future<Either<Failure, void>> deleteCostFieldOption(String optionId);

  /// Live-resolves what a `generated` field's code would be for
  /// [selections] (`{fieldId: optionId}`) without persisting anything —
  /// null if the org has no generated field configured or the selection is
  /// incomplete. Calls the `resolve_org_cost_center_code` RPC.
  Future<Either<Failure, String?>> previewCostCenterCode({
    required String orgId,
    required Map<String, String> selections,
  });
}
