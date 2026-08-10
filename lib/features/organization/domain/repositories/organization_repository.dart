import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/org_cost_field.dart';
import '../entities/org_cost_field_option.dart';
import '../entities/org_feature_override.dart';
import '../entities/org_join_code.dart';
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

  Future<Either<Failure, void>> rejectExpense(String expenseId, String reason);

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

  /// All join codes for [orgId] — active, expired, exhausted, and revoked
  /// alike (the admin list screen distinguishes them via
  /// [OrgJoinCode.isActive]). Admin-only server-side (stage35's
  /// `org_join_codes_admin_select` RLS policy).
  Future<Either<Failure, List<OrgJoinCode>>> fetchJoinCodes(String orgId);

  /// Generates a new join code scoped to [orgId] and, optionally,
  /// [costFieldOptionId] (a department). Admin-only — enforced inside the
  /// `generate_org_join_code` RPC itself (SECURITY DEFINER bypasses RLS,
  /// so the RPC's own check is the authorization). [role] is restricted to
  /// [OrgMemberRole.admin]/[OrgMemberRole.member] server-side; a join code
  /// can never mint an [OrgMemberRole.owner].
  Future<Either<Failure, OrgJoinCode>> generateJoinCode({
    required String orgId,
    required OrgMemberRole role,
    String? costFieldOptionId,
    DateTime? expiresAt,
    int? maxUses,
  });

  /// Revokes a join code early. Admin-only, enforced inside the RPC.
  Future<Either<Failure, void>> revokeJoinCode(String codeId);

  /// Redeems [code], adding the *currently authenticated* user to whichever
  /// organization the code is scoped to — never a client-supplied org or
  /// user id, both are resolved entirely server-side inside
  /// `redeem_org_join_code`. Unlike every other method on this interface,
  /// the caller does not need to already be a member (or even know) of the
  /// target organization; the code's own validity is the only credential.
  /// Returns a [ServerFailure] carrying the RPC's own message for every
  /// rejection reason (invalid/expired/revoked/exhausted/already-a-member),
  /// since that message is exactly what should be shown to the user.
  Future<Either<Failure, Organization>> redeemJoinCode(String code);

  /// Sets (or, passing null, clears) the org-wide default expense
  /// auto-approval threshold. Admin-only, enforced inside the
  /// `set_org_default_approval_threshold` RPC — `organizations` has no
  /// admin-scoped update RLS policy (owner-only), so this is an RPC rather
  /// than a plain client update. See `stage39_department_overrides.sql`.
  Future<Either<Failure, void>> setOrgDefaultApprovalThreshold({
    required String orgId,
    double? threshold,
  });

  /// Sets (or, passing null, clears) [optionId]'s department-specific
  /// approval threshold, overriding the org default for members in that
  /// department. A plain client update — `org_cost_field_options_admin_write`
  /// already grants admins full row control.
  Future<Either<Failure, void>> setCostFieldOptionApprovalThreshold({
    required String optionId,
    double? threshold,
  });

  /// Every feature-flag override configured for [optionId]'s department.
  /// Admin-only server-side (`org_feature_overrides_admin_all` RLS).
  Future<Either<Failure, List<OrgFeatureOverride>>> fetchFeatureOverrides(
    String optionId,
  );

  /// Grants or revokes [optionId]'s department access to [featureKey]
  /// (upserts on `(cost_field_option_id, feature_key)` — toggling back and
  /// forth reuses the same row rather than deleting/recreating it, an
  /// audit-friendly soft toggle matching this schema's other status-log
  /// tables). Admin-only server-side.
  Future<Either<Failure, void>> setFeatureOverride({
    required String optionId,
    required String featureKey,
    required bool enabled,
  });
}
