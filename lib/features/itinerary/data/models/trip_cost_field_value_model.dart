import '../../domain/entities/trip_cost_field_value.dart';

class TripCostFieldValueModel extends TripCostFieldValue {
  const TripCostFieldValueModel({
    required super.itineraryId,
    required super.fieldId,
    required super.optionId,
  });

  factory TripCostFieldValueModel.fromJson(Map<String, dynamic> json) =>
      TripCostFieldValueModel(
        itineraryId: json['itinerary_id'] as String,
        fieldId: json['field_id'] as String,
        optionId: json['option_id'] as String,
      );
}
