import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_feature_override.dart';

void main() {
  test('two overrides with the same fields are equal', () {
    const a = OrgFeatureOverride(
      id: 'ovr-1',
      costFieldOptionId: 'opt-1',
      featureKey: 'google_maps',
      enabled: true,
    );
    const b = OrgFeatureOverride(
      id: 'ovr-1',
      costFieldOptionId: 'opt-1',
      featureKey: 'google_maps',
      enabled: true,
    );

    expect(a, b);
  });

  test('overrides differing only in enabled are not equal', () {
    const a = OrgFeatureOverride(
      id: 'ovr-1',
      costFieldOptionId: 'opt-1',
      featureKey: 'google_maps',
      enabled: true,
    );
    const b = OrgFeatureOverride(
      id: 'ovr-1',
      costFieldOptionId: 'opt-1',
      featureKey: 'google_maps',
      enabled: false,
    );

    expect(a, isNot(b));
  });
}
