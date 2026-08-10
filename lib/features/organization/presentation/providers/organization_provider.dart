import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/organization_remote_datasource.dart';
import '../../data/repositories/organization_repository_impl.dart';
import '../../domain/entities/org_cost_field.dart';
import '../../domain/entities/org_feature_override.dart';
import '../../domain/entities/org_join_code.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/organization.dart';
import '../../domain/entities/pending_expense_approval.dart';
import '../../domain/usecases/add_org_cost_field_option_usecase.dart';
import '../../domain/usecases/create_org_cost_field_usecase.dart';
import '../../domain/usecases/create_organization_usecase.dart';
import '../../domain/usecases/delete_org_cost_field_option_usecase.dart';
import '../../domain/usecases/delete_org_cost_field_usecase.dart';
import '../../domain/usecases/fetch_feature_overrides_usecase.dart';
import '../../domain/usecases/fetch_my_organizations_usecase.dart';
import '../../domain/usecases/fetch_org_cost_fields_usecase.dart';
import '../../domain/usecases/fetch_org_join_codes_usecase.dart';
import '../../domain/usecases/fetch_org_members_usecase.dart';
import '../../domain/usecases/fetch_pending_expense_approvals_usecase.dart';
import '../../domain/usecases/generate_org_join_code_usecase.dart';
import '../../domain/usecases/invite_org_member_usecase.dart';
import '../../domain/usecases/preview_cost_center_code_usecase.dart';
import '../../domain/usecases/redeem_org_join_code_usecase.dart';
import '../../domain/usecases/remove_org_member_usecase.dart';
import '../../domain/usecases/review_expense_usecase.dart';
import '../../domain/usecases/revoke_org_join_code_usecase.dart';
import '../../domain/usecases/set_cost_field_option_approval_threshold_usecase.dart';
import '../../domain/usecases/set_feature_override_usecase.dart';
import '../../domain/usecases/set_org_default_approval_threshold_usecase.dart';
import '../../domain/usecases/update_org_member_role_usecase.dart';

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

final organizationDataSourceProvider = Provider<OrganizationRemoteDataSource>(
  (_) => const OrganizationRemoteDataSourceImpl(),
);

final organizationRepositoryProvider = Provider<OrganizationRepositoryImpl>(
  (ref) => OrganizationRepositoryImpl(
    dataSource: ref.watch(organizationDataSourceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Use-case providers
// ---------------------------------------------------------------------------

final createOrganizationUseCaseProvider = Provider<CreateOrganizationUseCase>(
  (ref) => CreateOrganizationUseCase(ref.watch(organizationRepositoryProvider)),
);

final fetchMyOrganizationsUseCaseProvider =
    Provider<FetchMyOrganizationsUseCase>(
      (ref) => FetchMyOrganizationsUseCase(
        ref.watch(organizationRepositoryProvider),
      ),
    );

final fetchOrgMembersUseCaseProvider = Provider<FetchOrgMembersUseCase>(
  (ref) => FetchOrgMembersUseCase(ref.watch(organizationRepositoryProvider)),
);

final inviteOrgMemberUseCaseProvider = Provider<InviteOrgMemberUseCase>(
  (ref) => InviteOrgMemberUseCase(ref.watch(organizationRepositoryProvider)),
);

final updateOrgMemberRoleUseCaseProvider = Provider<UpdateOrgMemberRoleUseCase>(
  (ref) =>
      UpdateOrgMemberRoleUseCase(ref.watch(organizationRepositoryProvider)),
);

final removeOrgMemberUseCaseProvider = Provider<RemoveOrgMemberUseCase>(
  (ref) => RemoveOrgMemberUseCase(ref.watch(organizationRepositoryProvider)),
);

final fetchPendingExpenseApprovalsUseCaseProvider =
    Provider<FetchPendingExpenseApprovalsUseCase>(
      (ref) => FetchPendingExpenseApprovalsUseCase(
        ref.watch(organizationRepositoryProvider),
      ),
    );

final reviewExpenseUseCaseProvider = Provider<ReviewExpenseUseCase>(
  (ref) => ReviewExpenseUseCase(ref.watch(organizationRepositoryProvider)),
);

final fetchOrgCostFieldsUseCaseProvider = Provider<FetchOrgCostFieldsUseCase>(
  (ref) => FetchOrgCostFieldsUseCase(ref.watch(organizationRepositoryProvider)),
);

final createOrgCostFieldUseCaseProvider = Provider<CreateOrgCostFieldUseCase>(
  (ref) => CreateOrgCostFieldUseCase(ref.watch(organizationRepositoryProvider)),
);

final deleteOrgCostFieldUseCaseProvider = Provider<DeleteOrgCostFieldUseCase>(
  (ref) => DeleteOrgCostFieldUseCase(ref.watch(organizationRepositoryProvider)),
);

final addOrgCostFieldOptionUseCaseProvider =
    Provider<AddOrgCostFieldOptionUseCase>(
      (ref) => AddOrgCostFieldOptionUseCase(
        ref.watch(organizationRepositoryProvider),
      ),
    );

final deleteOrgCostFieldOptionUseCaseProvider =
    Provider<DeleteOrgCostFieldOptionUseCase>(
      (ref) => DeleteOrgCostFieldOptionUseCase(
        ref.watch(organizationRepositoryProvider),
      ),
    );

final previewCostCenterCodeUseCaseProvider =
    Provider<PreviewCostCenterCodeUseCase>(
      (ref) => PreviewCostCenterCodeUseCase(
        ref.watch(organizationRepositoryProvider),
      ),
    );

final fetchOrgJoinCodesUseCaseProvider = Provider<FetchOrgJoinCodesUseCase>(
  (ref) => FetchOrgJoinCodesUseCase(ref.watch(organizationRepositoryProvider)),
);

final generateOrgJoinCodeUseCaseProvider = Provider<GenerateOrgJoinCodeUseCase>(
  (ref) =>
      GenerateOrgJoinCodeUseCase(ref.watch(organizationRepositoryProvider)),
);

final revokeOrgJoinCodeUseCaseProvider = Provider<RevokeOrgJoinCodeUseCase>(
  (ref) => RevokeOrgJoinCodeUseCase(ref.watch(organizationRepositoryProvider)),
);

final redeemOrgJoinCodeUseCaseProvider = Provider<RedeemOrgJoinCodeUseCase>(
  (ref) => RedeemOrgJoinCodeUseCase(ref.watch(organizationRepositoryProvider)),
);

final setOrgDefaultApprovalThresholdUseCaseProvider =
    Provider<SetOrgDefaultApprovalThresholdUseCase>(
      (ref) => SetOrgDefaultApprovalThresholdUseCase(
        ref.watch(organizationRepositoryProvider),
      ),
    );

final setCostFieldOptionApprovalThresholdUseCaseProvider =
    Provider<SetCostFieldOptionApprovalThresholdUseCase>(
      (ref) => SetCostFieldOptionApprovalThresholdUseCase(
        ref.watch(organizationRepositoryProvider),
      ),
    );

final fetchFeatureOverridesUseCaseProvider =
    Provider<FetchFeatureOverridesUseCase>(
      (ref) => FetchFeatureOverridesUseCase(
        ref.watch(organizationRepositoryProvider),
      ),
    );

final setFeatureOverrideUseCaseProvider = Provider<SetFeatureOverrideUseCase>(
  (ref) => SetFeatureOverrideUseCase(ref.watch(organizationRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Read providers
// ---------------------------------------------------------------------------

/// Organizations the current user belongs to. No realtime stream — org
/// membership changes rarely enough that a one-shot fetch (refreshed via
/// `ref.invalidate` after create/invite actions) is simpler than a
/// `StreamProvider`, matching `tripEmailAliasProvider`'s reasoning.
final myOrganizationsProvider = FutureProvider<List<Organization>>((ref) async {
  final result = await ref.watch(fetchMyOrganizationsUseCaseProvider).call();
  return result.fold((f) => throw Exception(f.message), (orgs) => orgs);
});

final orgMembersProvider = FutureProvider.family<List<OrgMember>, String>((
  ref,
  orgId,
) async {
  final result = await ref.watch(fetchOrgMembersUseCaseProvider).call(orgId);
  return result.fold((f) => throw Exception(f.message), (members) => members);
});

final pendingApprovalsProvider =
    FutureProvider.family<List<PendingExpenseApproval>, String>((
      ref,
      orgId,
    ) async {
      final result = await ref
          .watch(fetchPendingExpenseApprovalsUseCaseProvider)
          .call(orgId);
      return result.fold((f) => throw Exception(f.message), (list) => list);
    });

/// An org's cost-tracking structure. No realtime — a field builder is
/// admin-configured occasionally, not live-collaborative; refreshed via
/// `ref.invalidate` after create/delete actions, same reasoning as
/// `myOrganizationsProvider`.
final orgCostFieldsProvider = FutureProvider.family<List<OrgCostField>, String>(
  (ref, orgId) async {
    final result = await ref
        .watch(fetchOrgCostFieldsUseCaseProvider)
        .call(orgId);
    return result.fold((f) => throw Exception(f.message), (fields) => fields);
  },
);

/// An org's join codes (active, expired, exhausted, and revoked alike). No
/// realtime — an admin-only management screen, refreshed via
/// `ref.invalidate` after generate/revoke actions, same reasoning as
/// [orgCostFieldsProvider].
final orgJoinCodesProvider = FutureProvider.family<List<OrgJoinCode>, String>((
  ref,
  orgId,
) async {
  final result = await ref.watch(fetchOrgJoinCodesUseCaseProvider).call(orgId);
  return result.fold((f) => throw Exception(f.message), (codes) => codes);
});

/// Feature-flag overrides configured for one department (cost field
/// option). No realtime, same reasoning as [orgCostFieldsProvider] —
/// admin-configured occasionally, refreshed via `ref.invalidate` after a
/// toggle.
final featureOverridesProvider =
    FutureProvider.family<List<OrgFeatureOverride>, String>((
      ref,
      optionId,
    ) async {
      final result = await ref
          .watch(fetchFeatureOverridesUseCaseProvider)
          .call(optionId);
      return result.fold(
        (f) => throw Exception(f.message),
        (overrides) => overrides,
      );
    });
