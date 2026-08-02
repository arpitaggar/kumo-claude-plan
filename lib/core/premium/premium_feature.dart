import 'package:equatable/equatable.dart';

/// A row from `public.feature_flags` — a small, admin-controlled table (see
/// stage21_trip_segments.sql) used to gate premium features without a code
/// deploy. Only the service role can write these; the client only reads.
class PremiumFeature extends Equatable {
  const PremiumFeature({
    required this.featureKey,
    required this.requiresPremium,
    this.freeUntil,
  });

  factory PremiumFeature.fromJson(Map<String, dynamic> json) => PremiumFeature(
        featureKey: json['feature_key'] as String,
        requiresPremium: json['requires_premium'] as bool? ?? false,
        freeUntil: json['free_until'] != null
            ? DateTime.parse(json['free_until'] as String).toUtc()
            : null,
      );

  final String featureKey;
  final bool requiresPremium;

  /// If set and still in the future, the feature is free for everyone
  /// regardless of [requiresPremium] — a temporary grace-period override.
  final DateTime? freeUntil;

  /// Whether this feature is currently locked behind premium for a
  /// non-premium user.
  bool get isGated =>
      requiresPremium && (freeUntil == null || DateTime.now().isAfter(freeUntil!));

  @override
  List<Object?> get props => [featureKey, requiresPremium, freeUntil];
}

/// Known feature keys, matching `feature_flags.feature_key` rows.
class PremiumFeatureKeys {
  const PremiumFeatureKeys._();

  static const googleMaps = 'google_maps';
}
