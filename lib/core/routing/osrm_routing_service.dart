import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/itinerary/domain/entities/transport_mode.dart';
import '../../features/itinerary/domain/entities/waypoint.dart';
import '../utils/logger.dart';
import 'routing_service.dart';

/// Free road/footpath routing via OSRM's public demo server — same free,
/// no-key OSM ecosystem as `NominatimGeocodingService`, used for the
/// OpenStreetMap map engine.
///
/// The public demo server has historically only reliably served the
/// `driving` profile (`foot` may 400/404 depending on its current OSM
/// extract), so every failure mode here — non-200, unparseable body,
/// `code != "Ok"` — is swallowed and reported as `null` rather than thrown.
/// The caller's fallback (the existing straight/curved line) is a
/// perfectly fine degraded experience; a walking segment just not getting
/// road-accurate geometry yet is not worth surfacing as a user-facing error.
class OsrmRoutingService implements RoutingService {
  OsrmRoutingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _host = 'router.project-osrm.org';

  String? _profileFor(TransportMode mode) => switch (mode) {
    TransportMode.car ||
    TransportMode.motorcycle ||
    TransportMode.bus => 'driving',
    TransportMode.walk => 'foot',
    _ => null,
  };

  @override
  Future<List<(double, double)>?> route({
    required Waypoint origin,
    required Waypoint destination,
    required TransportMode mode,
  }) async {
    final profile = _profileFor(mode);
    if (profile == null) {
      return null;
    }

    final uri = Uri.https(
      _host,
      '/route/v1/$profile/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}',
      {'overview': 'full', 'geometries': 'geojson'},
    );

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['code'] != 'Ok') {
        return null;
      }

      final routes = decoded['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return null;
      }

      final geometry =
          (routes.first as Map<String, dynamic>)['geometry']
              as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      if (coordinates.length < 2) {
        return null;
      }

      // GeoJSON coordinates are [lng, lat] — flip to this app's (lat, lng)
      // convention (see route_curve.dart / route_path_sampling.dart).
      return [
        for (final point in coordinates)
          (
            ((point as List<dynamic>)[1] as num).toDouble(),
            (point[0] as num).toDouble(),
          ),
      ];
    } catch (e, st) {
      AppLogger.warning(
        'OSRM routing failed, falling back to straight line: $e\n$st',
      );
      return null;
    }
  }
}
