import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../config/brand.dart';
import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/org_cost_field.dart';
import '../../domain/entities/org_member.dart';
import '../models/org_cost_field_model.dart';
import '../models/org_cost_field_option_model.dart';
import '../models/org_feature_override_model.dart';
import '../models/org_join_code_model.dart';
import '../models/org_member_model.dart';
import '../models/organization_model.dart';
import '../models/pending_expense_approval_model.dart';

abstract class OrganizationRemoteDataSource {
  Future<OrganizationModel> createOrganization({
    required String name,
    required String slug,
  });

  Future<List<OrganizationModel>> fetchMyOrganizations();

  Future<List<OrgMemberModel>> fetchOrgMembers(String orgId);

  /// Throws [NotFoundException] if no Kumo account exists for [email] —
  /// inviting someone without an account yet is out of scope for this
  /// version (see stage28's migration comment on scope).
  Future<OrgMemberModel> inviteMember({
    required String orgId,
    required String email,
    required OrgMemberRole role,
  });

  Future<void> updateMemberRole({
    required String orgMemberId,
    required OrgMemberRole role,
  });

  Future<void> removeMember(String orgMemberId);

  Future<List<PendingExpenseApprovalModel>> fetchPendingApprovals(String orgId);

  Future<void> approveExpense(String expenseId);

  Future<void> rejectExpense(String expenseId, String reason);

  Future<List<OrgCostFieldModel>> fetchOrgCostFields(String orgId);

  Future<OrgCostFieldModel> createCostField({
    required String orgId,
    required String label,
    required CostFieldType fieldType,
    required String separator,
    required List<String> sourceFieldIds,
  });

  /// Throws [ServerException] with a friendly message (not the raw
  /// Postgres FK-restrict error) if the field is still in use.
  Future<void> deleteCostField(String fieldId);

  Future<OrgCostFieldOptionModel> addCostFieldOption({
    required String fieldId,
    required String value,
    required String code,
  });

  /// Throws [ServerException] with a friendly message if the option is
  /// still assigned to an existing trip.
  Future<void> deleteCostFieldOption(String optionId);

  Future<String?> previewCostCenterCode({
    required String orgId,
    required Map<String, String> selections,
  });

  Future<List<OrgJoinCodeModel>> fetchJoinCodes(String orgId);

  Future<OrgJoinCodeModel> generateJoinCode({
    required String orgId,
    required OrgMemberRole role,
    String? costFieldOptionId,
    DateTime? expiresAt,
    int? maxUses,
  });

  Future<void> revokeJoinCode(String codeId);

  /// Returns the joined [OrganizationModel]. Throws [ServerException]
  /// carrying `redeem_org_join_code`'s own raised message for every
  /// rejection reason (invalid/expired/revoked/exhausted/already-a-member)
  /// — that message is exactly what should reach the user.
  Future<OrganizationModel> redeemJoinCode(String code);

  Future<void> setOrgDefaultApprovalThreshold({
    required String orgId,
    double? threshold,
  });

  Future<void> setCostFieldOptionApprovalThreshold({
    required String optionId,
    double? threshold,
  });

  Future<List<OrgFeatureOverrideModel>> fetchFeatureOverrides(String optionId);

  Future<void> setFeatureOverride({
    required String optionId,
    required String featureKey,
    required bool enabled,
  });
}

class OrganizationRemoteDataSourceImpl implements OrganizationRemoteDataSource {
  const OrganizationRemoteDataSourceImpl();

  static const _orgsTable = 'organizations';
  static const _membersTable = 'org_members';
  static const _expensesTable = 'expenses';
  static const _costFieldsTable = 'org_cost_fields';
  static const _costFieldOptionsTable = 'org_cost_field_options';
  static const _costFieldSourcesTable = 'org_cost_field_sources';
  // org_cost_field_sources has two FKs to org_cost_fields
  // (generated_field_id, source_field_id — see stage30_org_cost_fields.sql),
  // so PostgREST can't auto-resolve which one embeds "this field's list of
  // source fields" without the `!generated_field_id` hint — omitting it
  // throws "more than one relationship was found" on every call, since it's
  // a query-planning error, not a data-dependent one.
  static const _costFieldsEmbedSelect =
      '*, org_cost_field_options(*), '
      'org_cost_field_sources!generated_field_id(source_field_id, position)';
  static const _joinCodesTable = 'org_join_codes';
  static const _featureOverridesTable = 'org_feature_overrides';

  @override
  Future<OrganizationModel> createOrganization({
    required String name,
    required String slug,
  }) async {
    try {
      final uid = KumoSupabaseClient.auth.currentUser!.id;
      final rows = await KumoSupabaseClient.client.from(_orgsTable).insert({
        'name': name,
        'slug': slug,
        'owner_id': uid,
      }).select();
      return OrganizationModel.fromJson(rows.first);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<OrganizationModel>> fetchMyOrganizations() async {
    try {
      final rows = await KumoSupabaseClient.client
          .from(_orgsTable)
          .select()
          .order('created_at');
      return rows.map(OrganizationModel.fromJson).toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<OrgMemberModel>> fetchOrgMembers(String orgId) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from(_membersTable)
          .select()
          .eq('org_id', orgId)
          .order('joined_at');
      return rows.map(OrgMemberModel.fromJson).toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<OrgMemberModel> inviteMember({
    required String orgId,
    required String email,
    required OrgMemberRole role,
  }) async {
    try {
      final profileRows = await KumoSupabaseClient.client
          .from('profiles')
          .select('id, display_name')
          .eq('email', email.trim().toLowerCase())
          .limit(1);

      if (profileRows.isEmpty) {
        throw NotFoundException(
          message: 'No ${Brand.appName} account found for $email',
        );
      }
      final profile = profileRows.first;

      final rows = await KumoSupabaseClient.client.from(_membersTable).insert({
        'org_id': orgId,
        'user_id': profile['id'],
        'user_name': profile['display_name'] ?? '',
        'role': role.name,
      }).select();

      return OrgMemberModel.fromJson(rows.first);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> updateMemberRole({
    required String orgMemberId,
    required OrgMemberRole role,
  }) async {
    try {
      await KumoSupabaseClient.client
          .from(_membersTable)
          .update({'role': role.name})
          .eq('id', orgMemberId);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> removeMember(String orgMemberId) async {
    try {
      await KumoSupabaseClient.client
          .from(_membersTable)
          .delete()
          .eq('id', orgMemberId);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<PendingExpenseApprovalModel>> fetchPendingApprovals(
    String orgId,
  ) async {
    try {
      // Goes through a SECURITY DEFINER RPC (stage32), not a raw embed of
      // `itineraries`, deliberately: org admins are never granted direct
      // table-level SELECT on itineraries (that was a data-exposure
      // vulnerability — see stage32's migration comment) — this function
      // does its own authorization check and returns only the columns this
      // screen needs.
      final rows =
          await KumoSupabaseClient.client.rpc(
                'fetch_org_pending_approvals',
                params: {'p_org_id': orgId},
              )
              as List<dynamic>;
      return rows
          .cast<Map<String, dynamic>>()
          .map(PendingExpenseApprovalModel.fromJson)
          .toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> approveExpense(String expenseId) async {
    try {
      final uid = KumoSupabaseClient.auth.currentUser!.id;
      await KumoSupabaseClient.client
          .from(_expensesTable)
          .update({
            'approval_status': 'approved',
            'reviewed_by': uid,
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            'rejection_reason': null,
          })
          .eq('id', expenseId);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> rejectExpense(String expenseId, String reason) async {
    try {
      final uid = KumoSupabaseClient.auth.currentUser!.id;
      await KumoSupabaseClient.client
          .from(_expensesTable)
          .update({
            'approval_status': 'rejected',
            'reviewed_by': uid,
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            'rejection_reason': reason,
          })
          .eq('id', expenseId);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<OrgCostFieldModel>> fetchOrgCostFields(String orgId) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from(_costFieldsTable)
          .select(_costFieldsEmbedSelect)
          .eq('org_id', orgId)
          .order('sort_order');
      return rows.map(OrgCostFieldModel.fromJson).toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<OrgCostFieldModel> createCostField({
    required String orgId,
    required String label,
    required CostFieldType fieldType,
    required String separator,
    required List<String> sourceFieldIds,
  }) async {
    try {
      final fieldRows =
          await KumoSupabaseClient.client.from(_costFieldsTable).insert({
            'org_id': orgId,
            'label': label,
            'field_type': fieldType.name,
            'separator': separator,
          }).select();
      final fieldId = fieldRows.first['id'] as String;

      if (sourceFieldIds.isNotEmpty) {
        await KumoSupabaseClient.client.from(_costFieldSourcesTable).insert([
          for (var i = 0; i < sourceFieldIds.length; i++)
            {
              'generated_field_id': fieldId,
              'source_field_id': sourceFieldIds[i],
              'position': i,
            },
        ]);
      }

      return OrgCostFieldModel(
        id: fieldId,
        orgId: orgId,
        label: label,
        fieldType: fieldType,
        separator: separator,
        sortOrder: fieldRows.first['sort_order'] as int? ?? 0,
        sourceFieldIds: sourceFieldIds,
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> deleteCostField(String fieldId) async {
    try {
      await KumoSupabaseClient.client
          .from(_costFieldsTable)
          .delete()
          .eq('id', fieldId);
    } on sb.PostgrestException catch (e) {
      if (e.code == '23503') {
        throw ServerException(
          message:
              "This field is used by an existing trip and can't be deleted",
        );
      }
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<OrgCostFieldOptionModel> addCostFieldOption({
    required String fieldId,
    required String value,
    required String code,
  }) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from(_costFieldOptionsTable)
          .insert({'field_id': fieldId, 'value': value, 'code': code})
          .select();
      return OrgCostFieldOptionModel.fromJson(rows.first);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> deleteCostFieldOption(String optionId) async {
    try {
      await KumoSupabaseClient.client
          .from(_costFieldOptionsTable)
          .delete()
          .eq('id', optionId);
    } on sb.PostgrestException catch (e) {
      if (e.code == '23503') {
        // Was worded for the trip-assignment case only; stage35's
        // org_join_codes.cost_field_option_id (ON DELETE RESTRICT) can now
        // also be what's blocking this delete, so the message stays
        // generic rather than claiming it must be a trip.
        throw ServerException(
          message: "This value is in use and can't be deleted",
        );
      }
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<String?> previewCostCenterCode({
    required String orgId,
    required Map<String, String> selections,
  }) async {
    try {
      final result = await KumoSupabaseClient.client.rpc(
        'resolve_org_cost_center_code',
        params: {'p_org_id': orgId, 'p_selections': selections},
      );
      return result as String?;
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<OrgJoinCodeModel>> fetchJoinCodes(String orgId) async {
    try {
      // A plain table select, not an RPC — org_join_codes_admin_select
      // (stage35) already scopes this correctly to org admins, and every
      // column here is something this list screen legitimately needs (see
      // that RLS policy's own comment on why this doesn't need the
      // fetch_org_pending_approvals-style RPC wrapper).
      final rows = await KumoSupabaseClient.client
          .from(_joinCodesTable)
          .select()
          .eq('org_id', orgId)
          .order('created_at', ascending: false);
      return rows.map(OrgJoinCodeModel.fromJson).toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<OrgJoinCodeModel> generateJoinCode({
    required String orgId,
    required OrgMemberRole role,
    String? costFieldOptionId,
    DateTime? expiresAt,
    int? maxUses,
  }) async {
    try {
      final row = await KumoSupabaseClient.client.rpc(
        'generate_org_join_code',
        params: {
          'p_org_id': orgId,
          'p_cost_field_option_id': costFieldOptionId,
          'p_role': role.name,
          'p_expires_at': expiresAt?.toIso8601String(),
          'p_max_uses': maxUses,
        },
      );
      return OrgJoinCodeModel.fromJson(row as Map<String, dynamic>);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> revokeJoinCode(String codeId) async {
    try {
      await KumoSupabaseClient.client.rpc(
        'revoke_org_join_code',
        params: {'p_code_id': codeId},
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<OrganizationModel> redeemJoinCode(String code) async {
    try {
      final row = await KumoSupabaseClient.client.rpc(
        'redeem_org_join_code',
        params: {'p_code': code},
      );
      return OrganizationModel.fromJson(row as Map<String, dynamic>);
    } on sb.PostgrestException catch (e) {
      // The RPC's raised message (invalid/expired/revoked/exhausted/
      // already-a-member/rate-limited) IS the display string — passed
      // through unchanged, same as every other guarded RPC in this app.
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> setOrgDefaultApprovalThreshold({
    required String orgId,
    double? threshold,
  }) async {
    try {
      await KumoSupabaseClient.client.rpc(
        'set_org_default_approval_threshold',
        params: {'p_org_id': orgId, 'p_threshold': threshold},
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> setCostFieldOptionApprovalThreshold({
    required String optionId,
    double? threshold,
  }) async {
    try {
      await KumoSupabaseClient.client
          .from(_costFieldOptionsTable)
          .update({'approval_threshold': threshold})
          .eq('id', optionId);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<OrgFeatureOverrideModel>> fetchFeatureOverrides(
    String optionId,
  ) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from(_featureOverridesTable)
          .select()
          .eq('cost_field_option_id', optionId);
      return rows.map(OrgFeatureOverrideModel.fromJson).toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> setFeatureOverride({
    required String optionId,
    required String featureKey,
    required bool enabled,
  }) async {
    try {
      await KumoSupabaseClient.client.from(_featureOverridesTable).upsert({
        'cost_field_option_id': optionId,
        'feature_key': featureKey,
        'enabled': enabled,
      }, onConflict: 'cost_field_option_id,feature_key');
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
