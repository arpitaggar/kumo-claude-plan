import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/data/models/trip_cost_field_value_model.dart';

void main() {
  group('TripCostFieldValueModel.fromJson', () {
    test('parses every field', () {
      final model = TripCostFieldValueModel.fromJson({
        'itinerary_id': 'trip-1',
        'field_id': 'field-1',
        'option_id': 'option-1',
      });

      expect(model.itineraryId, 'trip-1');
      expect(model.fieldId, 'field-1');
      expect(model.optionId, 'option-1');
    });
  });
}
