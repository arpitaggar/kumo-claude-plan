import '../../../../config/constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/itinerary_model.dart';

abstract class ItineraryRemoteDataSource {
  Future<List<ItineraryModel>> fetchItineraries(String userId);
  Future<ItineraryModel> fetchItinerary(String id);
  Future<ItineraryModel> createItinerary(ItineraryModel itinerary);
  Future<ItineraryModel> updateItinerary(ItineraryModel itinerary);
  Future<void> deleteItinerary(String id);
  Stream<ItineraryModel> watchItinerary(String id);
}

class ItineraryRemoteDataSourceImpl implements ItineraryRemoteDataSource {
  const ItineraryRemoteDataSourceImpl();

  @override
  Future<List<ItineraryModel>> fetchItineraries(String userId) async {
    try {
      final rows = await KumoSupabaseClient.getTable(
        AppConstants.itinerariesTable,
      ).select().eq('owner_id', userId).order('created_at', ascending: false);

      return (rows as List<dynamic>)
          .map((r) => ItineraryModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ItineraryModel> fetchItinerary(String id) async {
    try {
      final row = await KumoSupabaseClient.getTable(
        AppConstants.itinerariesTable,
      ).select().eq('id', id).single();

      return ItineraryModel.fromJson(row);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ItineraryModel> createItinerary(ItineraryModel itinerary) async {
    try {
      final row = await KumoSupabaseClient.getTable(
        AppConstants.itinerariesTable,
      ).insert(itinerary.toJson()).select().single();

      return ItineraryModel.fromJson(row);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ItineraryModel> updateItinerary(ItineraryModel itinerary) async {
    try {
      final row = await KumoSupabaseClient.getTable(
        AppConstants.itinerariesTable,
      ).update(itinerary.toJson()).eq('id', itinerary.id).select().single();

      return ItineraryModel.fromJson(row);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteItinerary(String id) async {
    try {
      await KumoSupabaseClient.getTable(
        AppConstants.itinerariesTable,
      ).delete().eq('id', id);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Stream<ItineraryModel> watchItinerary(String id) =>
      KumoSupabaseClient.getTable(AppConstants.itinerariesTable)
          .stream(primaryKey: ['id'])
          .eq('id', id)
          .map((rows) => ItineraryModel.fromJson(rows.first));
}
