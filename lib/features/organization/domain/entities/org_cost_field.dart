import 'package:equatable/equatable.dart';

import 'org_cost_field_option.dart';

/// One field in an org's custom cost-tracking structure — see stage30's
/// migration comment for the full picture. A [CostFieldType.select] field
/// carries its own admin-managed [options]; a [CostFieldType.generated]
/// field (at most one per org, enforced in the DB) has no options of its
/// own — its value is computed by concatenating the selected options of its
/// [sourceFieldIds], in order, joined by [separator].
class OrgCostField extends Equatable {
  const OrgCostField({
    required this.id,
    required this.orgId,
    required this.label,
    required this.fieldType,
    required this.separator,
    required this.sortOrder,
    this.options = const [],
    this.sourceFieldIds = const [],
  });

  final String id;
  final String orgId;
  final String label;
  final CostFieldType fieldType;
  final String separator;
  final int sortOrder;
  final List<OrgCostFieldOption> options;

  /// Ordered field ids this generated field draws from. Empty/meaningless
  /// for a [CostFieldType.select] field.
  final List<String> sourceFieldIds;

  @override
  List<Object?> get props => [
        id,
        orgId,
        label,
        fieldType,
        separator,
        sortOrder,
        options,
        sourceFieldIds,
      ];
}

enum CostFieldType { select, generated }
