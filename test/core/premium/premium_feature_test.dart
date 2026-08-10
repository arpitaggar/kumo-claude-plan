import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/premium/premium_feature.dart';

void main() {
  group('PremiumFeature.isGated', () {
    test('is false when requiresPremium is false', () {
      const feature = PremiumFeature(
        featureKey: 'google_maps',
        requiresPremium: false,
      );

      expect(feature.isGated, isFalse);
    });

    test('is true when requiresPremium is true and freeUntil is unset', () {
      const feature = PremiumFeature(
        featureKey: 'google_maps',
        requiresPremium: true,
      );

      expect(feature.isGated, isTrue);
    });

    test('is false when freeUntil is still in the future', () {
      final feature = PremiumFeature(
        featureKey: 'google_maps',
        requiresPremium: true,
        freeUntil: DateTime.now().add(const Duration(days: 1)),
      );

      expect(feature.isGated, isFalse);
    });

    test('is true when freeUntil has already passed', () {
      final feature = PremiumFeature(
        featureKey: 'google_maps',
        requiresPremium: true,
        freeUntil: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(feature.isGated, isTrue);
    });
  });
}
