import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/environment.dart';
import '../../features/itinerary/domain/entities/transport_mode.dart';
import '../../features/itinerary/domain/entities/waypoint.dart';
import '../utils/logger.dart';
import 'routing_service.dart';

/// Real road/footpath routing via the Google Directions API, used for the
/// Google Maps map engine (already a premium, API-key-gated feature in this
/// app — see `lib/core/maps/CLAUDE.md`).
///
/// Requires `Environment.googleMapsApiKey` (a separate `--dart-define` from
/// the native-only Maps SDK key) and the Directions API to be enabled for
/// that key's Google Cloud project — a one-time Cloud Console step, same as
/// the original Maps SDK key setup.
///
/// Every failure mode (empty key, non-200, `status != "OK"`, no routes) is
/// swallowed and reported as `null` — same fallback contract as
/// `OsrmRoutingService` (see its doc comment) — so a Directions API hiccup
/// just leaves the existing straight/curved line showing instead of
/// surfacing an error to the user.
class GoogleDirectionsRoutingService implements RoutingService {
  GoogleDirectionsRoutingService({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? Environment.googleMapsApiKey;

  final http.Client _client;

  /// Defaults to `Environment.googleMapsApiKey`; injectable (like [_client])
  /// so tests aren't at the mercy of `String.fromEnvironment` always
  /// resolving empty outside a `--dart-define` build.
  final String _apiKey;

  static const _host = 'maps.googleapis.com';

  String? _modeFor(TransportMode mode) => switch (mode) {
    TransportMode.car ||
    TransportMode.motorcycle ||
    TransportMode.bus => 'driving',
    TransportMode.walk => 'walking',
    _ => null,
  };

  @override
  Future<List<(double, double)>?> route({
    required Waypoint origin,
    required Waypoint destination,
    required TransportMode mode,
  }) async {
    final travelMode = _modeFor(mode);
    if (travelMode == null || _apiKey.isEmpty) {
      return null;
    }

    final uri = Uri.https(_host, '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': travelMode,
      'key': _apiKey,
    });

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['status'] != 'OK') {
        return null;
      }

      final routes = decoded['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return null;
      }

      final overviewPolyline =
          (routes.first as Map<String, dynamic>)['overview_polyline']
              as Map<String, dynamic>?;
      final encoded = overviewPolyline?['points'] as String?;
      if (encoded == null || encoded.isEmpty) {
        return null;
      }

      final path = _decodePolyline(encoded);
      return path.length < 2 ? null : path;
    } catch (e, st) {
      AppLogger.warning(
        'Google Directions routing failed, falling back to straight line: $e\n$st',
      );
      return null;
    }
  }
}

/// Standard Google encoded-polyline algorithm decoder (precision 1e5) — no
/// existing dependency in this app decodes these, so it's hand-rolled here
/// rather than pulling in a package for ~20 lines of well-known, stable
/// bit-twiddling.
List<(double, double)> _decodePolyline(String encoded) {
  final points = <(double, double)>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  int nextDelta() {
    var result = 0;
    var shift = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  }

  while (index < encoded.length) {
    lat += nextDelta();
    lng += nextDelta();
    points.add((lat / 1e5, lng / 1e5));
  }

  return points;
}
