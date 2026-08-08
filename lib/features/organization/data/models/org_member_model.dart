import '../../domain/entities/org_member.dart';

class OrgMemberModel extends OrgMember {
  const OrgMemberModel({
    required super.id,
    required super.orgId,
    required super.userId,
    required super.userName,
    required super.role,
    required super.joinedAt,
  });

  factory OrgMemberModel.fromJson(Map<String, dynamic> json) => OrgMemberModel(
        id: json['id'] as String,
        orgId: json['org_id'] as String,
        userId: json['user_id'] as String,
        userName: json['user_name'] as String? ?? '',
        role: OrgMemberRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => OrgMemberRole.member,
        ),
        joinedAt: DateTime.parse(json['joined_at'] as String).toUtc(),
      );
}
