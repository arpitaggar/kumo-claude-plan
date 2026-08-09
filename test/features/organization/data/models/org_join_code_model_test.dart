import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/organization/data/models/org_join_code_model.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_member.dart';

void main() {
  group('OrgJoinCodeModel.fromJson', () {
    test('parses all fields', () {
      final model = OrgJoinCodeModel.fromJson({
        'id': 'code-1',
        'org_id': 'org-1',
        'cost_field_option_id': 'option-1',
        'role': 'admin',
        'code': 'ABC123XYZ0',
        'expires_at': '2026-02-01T00:00:00.000Z',
        'max_uses': 5,
        'uses_count': 2,
        'revoked_at': '2026-01-15T00:00:00.000Z',
        'created_by': 'user-1',
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(model.id, 'code-1');
      expect(model.orgId, 'org-1');
      expect(model.costFieldOptionId, 'option-1');
      expect(model.role, OrgMemberRole.admin);
      expect(model.code, 'ABC123XYZ0');
      expect(model.expiresAt, DateTime.utc(2026, 2, 1));
      expect(model.maxUses, 5);
      expect(model.usesCount, 2);
      expect(model.revokedAt, DateTime.utc(2026, 1, 15));
      expect(model.createdBy, 'user-1');
      expect(model.createdAt, DateTime.utc(2026, 1, 1));
    });

    test(
      'defaults every nullable field to null/0 when absent from the row',
      () {
        final model = OrgJoinCodeModel.fromJson({
          'id': 'code-1',
          'org_id': 'org-1',
          'role': 'member',
          'code': 'ABC123XYZ0',
          'created_by': 'user-1',
          'created_at': '2026-01-01T00:00:00.000Z',
        });

        expect(model.costFieldOptionId, isNull);
        expect(model.expiresAt, isNull);
        expect(model.maxUses, isNull);
        expect(model.usesCount, 0);
        expect(model.revokedAt, isNull);
      },
    );

    test('falls back to member for an unrecognised role', () {
      final model = OrgJoinCodeModel.fromJson({
        'id': 'code-1',
        'org_id': 'org-1',
        'role': 'superadmin',
        'code': 'ABC123XYZ0',
        'created_by': 'user-1',
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(model.role, OrgMemberRole.member);
    });
  });
}
