import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'premium_datasource.dart';
import 'premium_feature.dart';
import 'profile_status.dart';
import 'profile_status_datasource.dart';

final premiumFeatureDataSourceProvider = Provider<PremiumFeatureDataSource>(
  (_) => const PremiumFeatureDataSourceImpl(),
);

/// All `feature_flags` rows, keyed by `feature_key`. Small, rarely-changing
/// table — fetched once per session rather than streamed.
final featureFlagsProvider = FutureProvider<Map<String, PremiumFeature>>((
  ref,
) async {
  final flags = await ref.watch(premiumFeatureDataSourceProvider).fetchAll();
  return {for (final f in flags) f.featureKey: f};
});

final profileStatusDataSourceProvider = Provider<ProfileStatusDataSource>(
  (_) => const ProfileStatusDataSourceImpl(),
);

/// The signed-in user's current `profile_status` row (see profile_status.dart
/// for why this is a log row rather than a flat boolean/column).
final currentProfileStatusProvider = FutureProvider<ProfileStatus?>(
  (ref) => ref.watch(profileStatusDataSourceProvider).fetchCurrent(),
);

/// Whether the signed-in user is currently premium — covers a signup trial,
/// a support-granted goodwill extension, or an active paid subscription, all
/// through the same profile_status log. No self-serve upgrade flow yet.
final isPremiumUserProvider = Provider<bool>((ref) {
  final status = ref.watch(currentProfileStatusProvider).valueOrNull;
  return status?.isCurrentlyPremium ?? false;
});

/// Whether any org department the signed-in user belongs to has an
/// override granting `featureKey` — see
/// `PremiumFeatureDataSource.hasDepartmentOverride`.
final departmentFeatureOverrideProvider = FutureProvider.family<bool, String>(
  (ref, featureKey) => ref
      .watch(premiumFeatureDataSourceProvider)
      .hasDepartmentOverride(featureKey),
);

/// Whether the current user can use the feature named by the family's
/// `featureKey` argument right now.
///
/// A feature with no matching row (not yet seeded, or flags still loading)
/// defaults to allowed — missing data should never lock users out of a
/// feature that's meant to ship free. A gated feature is allowed either by
/// the user's own premium status or by a department-level override
/// (stage39) — either is sufficient, neither can revoke what the other grants.
final canUseFeatureProvider = Provider.family<bool, String>((ref, featureKey) {
  final feature = ref.watch(featureFlagsProvider).valueOrNull?[featureKey];
  if (feature == null || !feature.isGated) {
    return true;
  }
  if (ref.watch(isPremiumUserProvider)) {
    return true;
  }
  return ref.watch(departmentFeatureOverrideProvider(featureKey)).valueOrNull ??
      false;
});
