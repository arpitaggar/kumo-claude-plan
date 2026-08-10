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
    this.approvalThreshold,
  });

  final String id;
  final String fieldId;
  final String value;
  final String code;
  final int sortOrder;

  /// Department-specific expense auto-approval threshold, overriding the
  /// org-wide `Organization.defaultApprovalThreshold` for members with this
  /// option as their `cost_field_option_id`. Null defers to the org
  /// default. See `stage39_department_overrides.sql`.
  final double? approvalThreshold;

  @override
  List<Object?> get props => [
    id,
    fieldId,
    value,
    code,
    sortOrder,
    approvalThreshold,
  ];
}
