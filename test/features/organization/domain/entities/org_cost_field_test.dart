import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_cost_field.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_cost_field_option.dart';

void main() {
  test('exposes exactly two field types: select and generated', () {
    expect(CostFieldType.values, [
      CostFieldType.select,
      CostFieldType.generated,
    ]);
  });

  test('defaults options and sourceFieldIds to empty', () {
    const field = OrgCostField(
      id: 'field-1',
      orgId: 'org-1',
      label: 'Department',
      fieldType: CostFieldType.select,
      separator: '-',
      sortOrder: 0,
    );

    expect(field.options, isEmpty);
    expect(field.sourceFieldIds, isEmpty);
  });

  test(
    'two fields with the same fields (including nested options) are equal',
    () {
      const options = [
        OrgCostFieldOption(
          id: 'opt-1',
          fieldId: 'field-1',
          value: 'Sales',
          code: 'SAL',
          sortOrder: 0,
        ),
      ];
      const a = OrgCostField(
        id: 'field-1',
        orgId: 'org-1',
        label: 'Department',
        fieldType: CostFieldType.select,
        separator: '-',
        sortOrder: 0,
        options: options,
      );
      const b = OrgCostField(
        id: 'field-1',
        orgId: 'org-1',
        label: 'Department',
        fieldType: CostFieldType.select,
        separator: '-',
        sortOrder: 0,
        options: options,
      );

      expect(a, b);
    },
  );

  test('a generated field carries its ordered sourceFieldIds', () {
    const field = OrgCostField(
      id: 'field-3',
      orgId: 'org-1',
      label: 'Cost Center',
      fieldType: CostFieldType.generated,
      separator: '-',
      sortOrder: 2,
      sourceFieldIds: ['field-1', 'field-2'],
    );

    expect(field.sourceFieldIds, ['field-1', 'field-2']);
  });
}
