import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/travel_itinerary.dart';
import '../models/itinerary_model.dart';

class ItineraryLocalDataSource {
  static const _prefix = 'itinerary_cache_';

  Future<void> saveItineraries(
    String userId,
    List<TravelItinerary> itineraries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(
      itineraries.map((t) => ItineraryModel.fromEntity(t).toJson()).toList(),
    );
    await prefs.setString('$_prefix$userId', json);
  }

  Future<List<TravelItinerary>?> loadCached(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$userId');
    if (raw == null) {
      return null;
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((j) => ItineraryModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
