import 'package:equatable/equatable.dart';

/// A company/workspace whose trips can be tagged (`TravelItinerary.orgId`)
/// so an org admin gets narrow oversight of them — see stage28's migration.
class Organization extends Equatable {
  const Organization({
    required this.id,
    required this.name,
    required this.slug,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.defaultApprovalThreshold,
  });

  final String id;
  final String name;
  final String slug;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Org-wide default expense auto-approval threshold — an expense strictly
  /// under this amount auto-approves on submit instead of needing manual
  /// admin review. Null means no org-wide default (still overridable per
  /// department, see `OrgCostFieldOption.approvalThreshold`; if that's also
  /// null, everything needs manual review). See
  /// `stage39_department_overrides.sql`.
  final double? defaultApprovalThreshold;

  @override
  List<Object?> get props => [
    id,
    name,
    slug,
    ownerId,
    createdAt,
    updatedAt,
    defaultApprovalThreshold,
  ];
}
