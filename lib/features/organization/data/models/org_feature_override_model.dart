import '../../domain/entities/org_feature_override.dart';

class OrgFeatureOverrideModel extends OrgFeatureOverride {
  const OrgFeatureOverrideModel({
    required super.id,
    required super.costFieldOptionId,
    required super.featureKey,
    required super.enabled,
  });

  factory OrgFeatureOverrideModel.fromJson(Map<String, dynamic> json) =>
      OrgFeatureOverrideModel(
        id: json['id'] as String,
        costFieldOptionId: json['cost_field_option_id'] as String,
        featureKey: json['feature_key'] as String,
        enabled: json['enabled'] as bool? ?? true,
      );
}
