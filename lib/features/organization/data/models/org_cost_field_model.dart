import '../../domain/entities/org_cost_field.dart';
import 'org_cost_field_option_model.dart';

class OrgCostFieldModel extends OrgCostField {
  const OrgCostFieldModel({
    required super.id,
    required super.orgId,
    required super.label,
    required super.fieldType,
    required super.separator,
    required super.sortOrder,
    super.options,
    super.sourceFieldIds,
  });

  /// Expects [json] to come from a query embedding both nested resources,
  /// e.g. `.select('*, org_cost_field_options(*), '
  /// 'org_cost_field_sources(source_field_id, position)')` — see
  /// `OrganizationRemoteDataSourceImpl.fetchOrgCostFields`.
  factory OrgCostFieldModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['org_cost_field_options'] as List<dynamic>? ?? [];
    final options = rawOptions
        .map((o) => OrgCostFieldOptionModel.fromJson(o as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final rawSources = json['org_cost_field_sources'] as List<dynamic>? ?? [];
    final sortedSources = rawSources.cast<Map<String, dynamic>>().toList()
      ..sort((a, b) =>
          (a['position'] as int).compareTo(b['position'] as int));
    final sourceFieldIds =
        sortedSources.map((s) => s['source_field_id'] as String).toList();

    return OrgCostFieldModel(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      label: json['label'] as String,
      fieldType: CostFieldType.values.firstWhere(
        (t) => t.name == json['field_type'],
        orElse: () => CostFieldType.select,
      ),
      separator: json['separator'] as String? ?? '-',
      sortOrder: json['sort_order'] as int? ?? 0,
      options: options,
      sourceFieldIds: sourceFieldIds,
    );
  }
}
