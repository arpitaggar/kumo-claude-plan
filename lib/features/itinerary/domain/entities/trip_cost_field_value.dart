import 'package:equatable/equatable.dart';

/// One org cost-tracking field's assigned option on a specific trip — see
/// stage30's migration. Meaningless on a personal trip (no `orgId`).
class TripCostFieldValue extends Equatable {
  const TripCostFieldValue({
    required this.itineraryId,
    required this.fieldId,
    required this.optionId,
  });

  final String itineraryId;
  final String fieldId;
  final String optionId;

  @override
  List<Object?> get props => [itineraryId, fieldId, optionId];
}
