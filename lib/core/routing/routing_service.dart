import '../../features/itinerary/domain/entities/transport_mode.dart';
import '../../features/itinerary/domain/entities/waypoint.dart';

/// Fetches real road/footpath geometry for a trip leg, so the Route tab can
/// draw the actual route instead of a straight/bowed line between origin and
/// destination — see `route_map_view.dart`'s `_geoPath`.
abstract class RoutingService {
  /// Returns the routed path as (lat, lng) points, or `null` if no route
  /// could be found or [mode] isn't a routable one (the caller falls back to
  /// the existing straight/curved line rendering either way).
  Future<List<(double, double)>?> route({
    required Waypoint origin,
    required Waypoint destination,
    required TransportMode mode,
  });
}

/// The subset of [TransportMode] that actually follows a real road/footpath
/// network — flights, ferries and (non-driving) trains don't route the way
/// OSRM/Directions understand routing, so they keep the existing
/// straight/curved line unconditionally.
bool isRoutableMode(TransportMode mode) =>
    mode == TransportMode.car ||
    mode == TransportMode.motorcycle ||
    mode == TransportMode.bus ||
    mode == TransportMode.walk;
