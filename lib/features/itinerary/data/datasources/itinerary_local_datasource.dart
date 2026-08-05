import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/travel_itinerary.dart';
import '../models/itinerary_model.dart';

/// Offline-read cache of a user's itineraries, including budget figures and
/// item geolocation. Backed by secure storage (Android Keystore / iOS
/// Keychain), not SharedPreferences, which stores plaintext on disk (see
/// docs/SECURITY_AUDIT.md SEC-016).
class ItineraryLocalDataSource {
  const ItineraryLocalDataSource([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const _prefix = 'itinerary_cache_';

  Future<void> saveItineraries(
    String userId,
    List<TravelItinerary> itineraries,
  ) async {
    final json = jsonEncode(
      itineraries.map((t) => ItineraryModel.fromEntity(t).toJson()).toList(),
    );
    await _storage.write(key: '$_prefix$userId', value: json);
  }

  Future<List<TravelItinerary>?> loadCached(String userId) async {
    final raw = await _storage.read(key: '$_prefix$userId');
    if (raw == null) {
      return null;
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((j) => ItineraryModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
