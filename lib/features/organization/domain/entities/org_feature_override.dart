import 'package:equatable/equatable.dart';

/// Grants a department (`OrgCostFieldOption`) access to a premium feature
/// (`PremiumFeatureKeys`) regardless of individual members' own premium
/// status — grant-only, never a deny; see `stage39_department_overrides.sql`
/// and `canUseFeatureProvider`.
class OrgFeatureOverride extends Equatable {
  const OrgFeatureOverride({
    required this.id,
    required this.costFieldOptionId,
    required this.featureKey,
    required this.enabled,
  });

  final String id;
  final String costFieldOptionId;
  final String featureKey;
  final bool enabled;

  @override
  List<Object?> get props => [id, costFieldOptionId, featureKey, enabled];
}
