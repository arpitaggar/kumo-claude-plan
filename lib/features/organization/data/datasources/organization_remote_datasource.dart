import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/org_cost_field.dart';
import '../../domain/entities/org_member.dart';
import '../models/org_cost_field_model.dart';
import '../models/org_cost_field_option_model.dart';
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

  Future<List<PendingExpenseApprovalModel>> fetchPendingApprovals(
    String orgId,
  );

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
}

class OrganizationRemoteDataSourceImpl implements OrganizationRemoteDataSource {
  const OrganizationRemoteDataSourceImpl();

  static const _orgsTable = 'organizations';
  static const _membersTable = 'org_members';
  static const _expensesTable = 'expenses';
  static const _costFieldsTable = 'org_cost_fields';
  static const _costFieldOptionsTable = 'org_cost_field_options';
  static const _costFieldSourcesTable = 'org_cost_field_sources';
  static const _costFieldsEmbedSelect =
      '*, org_cost_field_options(*), org_cost_field_sources(source_field_id, position)';

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
          message: 'No Kumo account found for $email',
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
      final rows = await KumoSupabaseClient.client.rpc(
        'fetch_org_pending_approvals',
        params: {'p_org_id': orgId},
      ) as List<dynamic>;
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
      await KumoSupabaseClient.client.from(_expensesTable).update({
        'approval_status': 'approved',
        'reviewed_by': uid,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'rejection_reason': null,
      }).eq('id', expenseId);
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
      await KumoSupabaseClient.client.from(_expensesTable).update({
        'approval_status': 'rejected',
        'reviewed_by': uid,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'rejection_reason': reason,
      }).eq('id', expenseId);
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
      final fieldRows = await KumoSupabaseClient.client.from(_costFieldsTable).insert({
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
          message: "This field is used by an existing trip and can't be deleted",
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
      final rows = await KumoSupabaseClient.client.from(_costFieldOptionsTable).insert({
        'field_id': fieldId,
        'value': value,
        'code': code,
      }).select();
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
        throw ServerException(
          message: "This value is used by an existing trip and can't be deleted",
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
}
