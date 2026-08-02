import 'dart:convert';

import 'package:http/http.dart' as http;

import 'geocoding_service.dart';

/// Free geocoding via OSM's Nominatim search API.
///
/// Nominatim's usage policy requires a descriptive User-Agent identifying the
/// app, and enforces a hard 1 request/second rate limit — a debounced search
/// field alone doesn't guarantee that (a fast typer can still burst past it),
/// so requests are also throttled to a minimum spacing here.
class NominatimGeocodingService implements GeocodingService {
  NominatimGeocodingService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent = 'KumoTravelApp/1.0 (com.cygnus.travelKumo)';
  static const _minRequestSpacing = Duration(milliseconds: 1100);

  DateTime? _lastRequestAt;

  Future<void> _throttle() async {
    final last = _lastRequestAt;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < _minRequestSpacing) {
        await Future<void>.delayed(_minRequestSpacing - elapsed);
      }
    }
    _lastRequestAt = DateTime.now();
  }

  @override
  Future<List<GeocodingResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    await _throttle();

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '8',
    });

    final response = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      throw Exception('Geocoding request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((raw) {
          final entry = raw as Map<String, dynamic>;
          return GeocodingResult(
            name: entry['display_name'] as String,
            latitude: double.parse(entry['lat'] as String),
            longitude: double.parse(entry['lon'] as String),
          );
        })
        .toList();
  }
}
