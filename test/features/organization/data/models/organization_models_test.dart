import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/organization/data/models/org_cost_field_model.dart';
import 'package:kumo_claude/features/organization/data/models/org_cost_field_option_model.dart';
import 'package:kumo_claude/features/organization/data/models/org_member_model.dart';
import 'package:kumo_claude/features/organization/data/models/organization_model.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_cost_field.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_member.dart';

void main() {
  group('OrganizationModel.fromJson', () {
    test('parses all fields', () {
      final model = OrganizationModel.fromJson(const {
        'id': 'org-1',
        'name': 'Acme Corp',
        'slug': 'acme-corp',
        'owner_id': 'user-1',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-02T00:00:00.000Z',
      });

      expect(model.id, 'org-1');
      expect(model.name, 'Acme Corp');
      expect(model.slug, 'acme-corp');
      expect(model.ownerId, 'user-1');
      expect(model.createdAt, DateTime.utc(2026));
      expect(model.updatedAt, DateTime.utc(2026, 1, 2));
    });

    test('toJson only includes name/slug (server owns the rest)', () {
      final model = OrganizationModel.fromJson(const {
        'id': 'org-1',
        'name': 'Acme Corp',
        'slug': 'acme-corp',
        'owner_id': 'user-1',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-02T00:00:00.000Z',
      });

      expect(model.toJson(), {'name': 'Acme Corp', 'slug': 'acme-corp'});
    });
  });

  group('OrgMemberModel.fromJson', () {
    test('parses a known role', () {
      final model = OrgMemberModel.fromJson(const {
        'id': 'member-1',
        'org_id': 'org-1',
        'user_id': 'user-1',
        'user_name': 'Bob',
        'role': 'admin',
        'joined_at': '2026-01-01T00:00:00.000Z',
      });

      expect(model.role, OrgMemberRole.admin);
      expect(model.userName, 'Bob');
    });

    test('falls back to member for an unrecognised role', () {
      final model = OrgMemberModel.fromJson(const {
        'id': 'member-1',
        'org_id': 'org-1',
        'user_id': 'user-1',
        'user_name': 'Bob',
        'role': 'superadmin',
        'joined_at': '2026-01-01T00:00:00.000Z',
      });

      expect(model.role, OrgMemberRole.member);
    });

    test('defaults userName to empty string when absent', () {
      final model = OrgMemberModel.fromJson(const {
        'id': 'member-1',
        'org_id': 'org-1',
        'user_id': 'user-1',
        'role': 'member',
        'joined_at': '2026-01-01T00:00:00.000Z',
      });

      expect(model.userName, '');
    });
  });

  group('OrgCostFieldOptionModel.fromJson', () {
    test('parses all fields', () {
      final model = OrgCostFieldOptionModel.fromJson(const {
        'id': 'option-1',
        'field_id': 'field-1',
        'value': 'Sales',
        'code': 'SAL',
        'sort_order': 2,
      });

      expect(model.id, 'option-1');
      expect(model.value, 'Sales');
      expect(model.code, 'SAL');
      expect(model.sortOrder, 2);
    });

    test('defaults sortOrder to 0 when absent', () {
      final model = OrgCostFieldOptionModel.fromJson(const {
        'id': 'option-1',
        'field_id': 'field-1',
        'value': 'Sales',
        'code': 'SAL',
      });

      expect(model.sortOrder, 0);
    });
  });

  group('OrgCostFieldModel.fromJson', () {
    test('parses a select field and sorts embedded options by sortOrder', () {
      final model = OrgCostFieldModel.fromJson(const {
        'id': 'field-1',
        'org_id': 'org-1',
        'label': 'Department',
        'field_type': 'select',
        'separator': '-',
        'sort_order': 0,
        'org_cost_field_options': [
          {
            'id': 'option-2',
            'field_id': 'field-1',
            'value': 'Engineering',
            'code': 'ENG',
            'sort_order': 1,
          },
          {
            'id': 'option-1',
            'field_id': 'field-1',
            'value': 'Sales',
            'code': 'SAL',
            'sort_order': 0,
          },
        ],
      });

      expect(model.fieldType, CostFieldType.select);
      expect(model.options, hasLength(2));
      // Sorted by sort_order (0, 1), not embed order (1, 0).
      expect(model.options[0].value, 'Sales');
      expect(model.options[1].value, 'Engineering');
    });

    test('parses a generated field and orders sourceFieldIds by position', () {
      final model = OrgCostFieldModel.fromJson(const {
        'id': 'field-3',
        'org_id': 'org-1',
        'label': 'Cost Center',
        'field_type': 'generated',
        'separator': '-',
        'sort_order': 2,
        'org_cost_field_sources': [
          {'source_field_id': 'field-2', 'position': 1},
          {'source_field_id': 'field-1', 'position': 0},
        ],
      });

      expect(model.fieldType, CostFieldType.generated);
      expect(model.sourceFieldIds, ['field-1', 'field-2']);
    });

    test('defaults field_type to select for an unrecognised value', () {
      final model = OrgCostFieldModel.fromJson(const {
        'id': 'field-1',
        'org_id': 'org-1',
        'label': 'Department',
        'field_type': 'unknown',
        'sort_order': 0,
      });

      expect(model.fieldType, CostFieldType.select);
    });

    test('defaults separator/sortOrder/options/sourceFieldIds when absent', () {
      final model = OrgCostFieldModel.fromJson(const {
        'id': 'field-1',
        'org_id': 'org-1',
        'label': 'Department',
        'field_type': 'select',
      });

      expect(model.separator, '-');
      expect(model.sortOrder, 0);
      expect(model.options, isEmpty);
      expect(model.sourceFieldIds, isEmpty);
    });
  });
}
