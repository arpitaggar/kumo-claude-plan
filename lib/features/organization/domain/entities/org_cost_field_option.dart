import 'package:equatable/equatable.dart';

/// One admin-managed value for a [CostFieldType.select] [OrgCostField] —
/// e.g. for a "Department" field, `value: "Sales", code: "SAL"`. `code` is
/// the short token used when a generated field concatenates this option
/// into a cost-center code; see stage30's migration.
class OrgCostFieldOption extends Equatable {
  const OrgCostFieldOption({
    required this.id,
    required this.fieldId,
    required this.value,
    required this.code,
    required this.sortOrder,
  });

  final String id;
  final String fieldId;
  final String value;
  final String code;
  final int sortOrder;

  @override
  List<Object?> get props => [id, fieldId, value, code, sortOrder];
}
