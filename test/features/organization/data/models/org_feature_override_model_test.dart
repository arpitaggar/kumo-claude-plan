import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/organization/data/models/org_feature_override_model.dart';

void main() {
  group('OrgFeatureOverrideModel.fromJson', () {
    test('parses all fields', () {
      final model = OrgFeatureOverrideModel.fromJson(const {
        'id': 'ovr-1',
        'cost_field_option_id': 'opt-1',
        'feature_key': 'google_maps',
        'enabled': true,
      });

      expect(model.id, 'ovr-1');
      expect(model.costFieldOptionId, 'opt-1');
      expect(model.featureKey, 'google_maps');
      expect(model.enabled, isTrue);
    });

    test('defaults enabled to true when absent', () {
      final model = OrgFeatureOverrideModel.fromJson(const {
        'id': 'ovr-1',
        'cost_field_option_id': 'opt-1',
        'feature_key': 'google_maps',
      });

      expect(model.enabled, isTrue);
    });
  });
}
