import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/organization/data/models/org_cost_field_option_model.dart';

void main() {
  group('OrgCostFieldOptionModel.fromJson', () {
    final baseJson = <String, dynamic>{
      'id': 'opt-1',
      'field_id': 'field-1',
      'value': 'Sales',
      'code': 'SAL',
      'sort_order': 2,
    };

    test('parses approvalThreshold when present', () {
      final model = OrgCostFieldOptionModel.fromJson({
        ...baseJson,
        'approval_threshold': 75.5,
      });

      expect(model.approvalThreshold, 75.5);
    });

    test('defaults approvalThreshold to null when absent', () {
      final model = OrgCostFieldOptionModel.fromJson(baseJson);

      expect(model.approvalThreshold, isNull);
    });
  });
}
