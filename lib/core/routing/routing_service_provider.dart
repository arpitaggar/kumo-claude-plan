import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../maps/kumo_map_provider.dart';
import 'google_directions_routing_service.dart';
import 'osrm_routing_service.dart';
import 'routing_service.dart';

/// Dispatches to whichever routing backend matches the currently selected
/// map engine — mirrors `RouteMapView`'s own OSM-vs-Google dispatch, so a
/// segment's routed geometry always comes from the same ecosystem as the
/// tiles it's drawn on.
final routingServiceProvider = Provider<RoutingService>((ref) {
  final provider = ref.watch(mapProviderConfigProvider);
  return switch (provider) {
    KumoMapProvider.openStreetMap => OsrmRoutingService(),
    KumoMapProvider.googleMaps => GoogleDirectionsRoutingService(),
  };
});
