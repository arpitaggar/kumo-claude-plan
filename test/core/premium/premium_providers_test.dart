import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/premium/premium_datasource.dart';
import 'package:kumo_claude/core/premium/premium_feature.dart';
import 'package:kumo_claude/core/premium/premium_providers.dart';
import 'package:kumo_claude/core/premium/profile_status.dart';
import 'package:kumo_claude/core/premium/profile_status_datasource.dart';
import 'package:mocktail/mocktail.dart';

class MockPremiumFeatureDataSource extends Mock
    implements PremiumFeatureDataSource {}

class MockProfileStatusDataSource extends Mock
    implements ProfileStatusDataSource {}

void main() {
  late MockPremiumFeatureDataSource featureDataSource;
  late MockProfileStatusDataSource statusDataSource;

  const gatedFeature = PremiumFeature(
    featureKey: 'google_maps',
    requiresPremium: true,
  );

  setUp(() {
    featureDataSource = MockPremiumFeatureDataSource();
    statusDataSource = MockProfileStatusDataSource();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        premiumFeatureDataSourceProvider.overrideWithValue(featureDataSource),
        profileStatusDataSourceProvider.overrideWithValue(statusDataSource),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('an ungated feature is always allowed', () async {
    when(featureDataSource.fetchAll).thenAnswer((_) async => []);
    when(statusDataSource.fetchCurrent).thenAnswer((_) async => null);

    final container = buildContainer();
    await container.read(featureFlagsProvider.future);

    expect(container.read(canUseFeatureProvider('unknown_key')), isTrue);
  });

  test('a gated feature is allowed for a premium user', () async {
    when(featureDataSource.fetchAll).thenAnswer((_) async => [gatedFeature]);
    when(statusDataSource.fetchCurrent).thenAnswer(
      (_) async => ProfileStatus(
        id: 'status-1',
        userId: 'user-1',
        status: 'premium',
        reason: 'trial',
        createdAt: DateTime.utc(2026),
      ),
    );

    final container = buildContainer();
    await container.read(featureFlagsProvider.future);
    await container.read(currentProfileStatusProvider.future);

    expect(container.read(canUseFeatureProvider('google_maps')), isTrue);
  });

  test('a gated feature is denied for a non-premium user with no department '
      'override', () async {
    when(featureDataSource.fetchAll).thenAnswer((_) async => [gatedFeature]);
    when(statusDataSource.fetchCurrent).thenAnswer((_) async => null);
    when(
      () => featureDataSource.hasDepartmentOverride('google_maps'),
    ).thenAnswer((_) async => false);

    final container = buildContainer();
    await container.read(featureFlagsProvider.future);
    await container.read(currentProfileStatusProvider.future);
    await container.read(
      departmentFeatureOverrideProvider('google_maps').future,
    );

    expect(container.read(canUseFeatureProvider('google_maps')), isFalse);
  });

  test(
    // stage39_department_overrides.sql: a department override is on top
    // of, not a replacement for, the user's own premium status — either
    // one grants access.
    'a gated feature is allowed for a non-premium user whose department '
    'has an override',
    () async {
      when(featureDataSource.fetchAll).thenAnswer((_) async => [gatedFeature]);
      when(statusDataSource.fetchCurrent).thenAnswer((_) async => null);
      when(
        () => featureDataSource.hasDepartmentOverride('google_maps'),
      ).thenAnswer((_) async => true);

      final container = buildContainer();
      await container.read(featureFlagsProvider.future);
      await container.read(currentProfileStatusProvider.future);
      await container.read(
        departmentFeatureOverrideProvider('google_maps').future,
      );

      expect(container.read(canUseFeatureProvider('google_maps')), isTrue);
    },
  );
}
