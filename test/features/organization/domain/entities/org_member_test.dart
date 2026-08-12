import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_member.dart';

void main() {
  test('exposes exactly three roles: owner, admin, member', () {
    expect(OrgMemberRole.values, [
      OrgMemberRole.owner,
      OrgMemberRole.admin,
      OrgMemberRole.member,
    ]);
  });

  test('two members with the same fields are equal', () {
    final joinedAt = DateTime.utc(2026);
    const id = 'member-1';
    final a = OrgMember(
      id: id,
      orgId: 'org-1',
      userId: 'user-1',
      userName: 'Alice',
      role: OrgMemberRole.admin,
      joinedAt: joinedAt,
    );
    final b = OrgMember(
      id: id,
      orgId: 'org-1',
      userId: 'user-1',
      userName: 'Alice',
      role: OrgMemberRole.admin,
      joinedAt: joinedAt,
    );

    expect(a, b);
  });
}
