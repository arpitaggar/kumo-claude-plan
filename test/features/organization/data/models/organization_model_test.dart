import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/organization/data/models/organization_model.dart';

void main() {
  group('OrganizationModel.fromJson', () {
    final baseJson = <String, dynamic>{
      'id': 'org-1',
      'name': 'Acme Corp',
      'slug': 'acme-corp',
      'owner_id': 'user-1',
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
    };

    test('parses defaultApprovalThreshold when present', () {
      final model = OrganizationModel.fromJson({
        ...baseJson,
        'default_approval_threshold': 150,
      });

      expect(model.defaultApprovalThreshold, 150);
    });

    test('defaults defaultApprovalThreshold to null when absent', () {
      final model = OrganizationModel.fromJson(baseJson);

      expect(model.defaultApprovalThreshold, isNull);
    });
  });
}
