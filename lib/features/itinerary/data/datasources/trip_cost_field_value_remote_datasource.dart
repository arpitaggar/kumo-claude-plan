import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/trip_cost_field_value_model.dart';

abstract class TripCostFieldValueRemoteDataSource {
  Future<List<TripCostFieldValueModel>> fetchValues(String itineraryId);

  /// One batched upsert for every entry in [fieldIdToOptionId] — targets the
  /// `unique(itinerary_id, field_id)` constraint (not the row's own `id`
  /// primary key, which is generated per-insert) so re-saving a field the
  /// trip already has a value for updates it in place.
  Future<void> setValues(
    String itineraryId,
    Map<String, String> fieldIdToOptionId,
  );
}

class TripCostFieldValueRemoteDataSourceImpl
    implements TripCostFieldValueRemoteDataSource {
  const TripCostFieldValueRemoteDataSourceImpl();

  static const _table = 'trip_cost_field_values';

  @override
  Future<List<TripCostFieldValueModel>> fetchValues(String itineraryId) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from(_table)
          .select()
          .eq('itinerary_id', itineraryId);
      return rows.map(TripCostFieldValueModel.fromJson).toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> setValues(
    String itineraryId,
    Map<String, String> fieldIdToOptionId,
  ) async {
    if (fieldIdToOptionId.isEmpty) {
      return;
    }
    try {
      await KumoSupabaseClient.client.from(_table).upsert(
        [
          for (final entry in fieldIdToOptionId.entries)
            {
              'itinerary_id': itineraryId,
              'field_id': entry.key,
              'option_id': entry.value,
            },
        ],
        onConflict: 'itinerary_id,field_id',
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
