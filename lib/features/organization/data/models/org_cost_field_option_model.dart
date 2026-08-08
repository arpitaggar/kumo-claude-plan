import '../../domain/entities/org_cost_field_option.dart';

class OrgCostFieldOptionModel extends OrgCostFieldOption {
  const OrgCostFieldOptionModel({
    required super.id,
    required super.fieldId,
    required super.value,
    required super.code,
    required super.sortOrder,
  });

  factory OrgCostFieldOptionModel.fromJson(Map<String, dynamic> json) =>
      OrgCostFieldOptionModel(
        id: json['id'] as String,
        fieldId: json['field_id'] as String,
        value: json['value'] as String,
        code: json['code'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}
