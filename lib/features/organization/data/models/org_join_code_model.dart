import '../../domain/entities/org_join_code.dart';
import '../../domain/entities/org_member.dart';

class OrgJoinCodeModel extends OrgJoinCode {
  const OrgJoinCodeModel({
    required super.id,
    required super.orgId,
    required super.role,
    required super.code,
    required super.usesCount,
    required super.createdBy,
    required super.createdAt,
    super.costFieldOptionId,
    super.expiresAt,
    super.maxUses,
    super.revokedAt,
  });

  factory OrgJoinCodeModel.fromJson(Map<String, dynamic> json) =>
      OrgJoinCodeModel(
        id: json['id'] as String,
        orgId: json['org_id'] as String,
        costFieldOptionId: json['cost_field_option_id'] as String?,
        role: OrgMemberRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => OrgMemberRole.member,
        ),
        code: json['code'] as String,
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String).toUtc()
            : null,
        maxUses: json['max_uses'] as int?,
        usesCount: json['uses_count'] as int? ?? 0,
        revokedAt: json['revoked_at'] != null
            ? DateTime.parse(json['revoked_at'] as String).toUtc()
            : null,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      );
}
