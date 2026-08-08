import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_cost_field_option.dart';

void main() {
  test('two options with the same fields are equal', () {
    const a = OrgCostFieldOption(
      id: 'opt-1',
      fieldId: 'field-1',
      value: 'Sales',
      code: 'SAL',
      sortOrder: 0,
    );
    const b = OrgCostFieldOption(
      id: 'opt-1',
      fieldId: 'field-1',
      value: 'Sales',
      code: 'SAL',
      sortOrder: 0,
    );

    expect(a, b);
  });

  test('options with different codes are not equal', () {
    const a = OrgCostFieldOption(
      id: 'opt-1',
      fieldId: 'field-1',
      value: 'Sales',
      code: 'SAL',
      sortOrder: 0,
    );
    const b = OrgCostFieldOption(
      id: 'opt-1',
      fieldId: 'field-1',
      value: 'Sales',
      code: 'SLS',
      sortOrder: 0,
    );

    expect(a, isNot(b));
  });
}
