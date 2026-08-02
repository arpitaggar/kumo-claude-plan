import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart' as ll;

import '../../features/itinerary/domain/entities/transport_mode.dart';
import '../../features/itinerary/domain/entities/trip_segment.dart';
import '../../features/itinerary/domain/entities/waypoint.dart';
import 'kumo_map_provider.dart';

// Built-in Material icons only — material_design_icons_flutter's pinned
// version (7.0.7296) subclasses IconData, which the current Flutter SDK
// forbids now that IconData is a final class.
IconData iconForTransportMode(TransportMode mode) {
  switch (mode) {
    case TransportMode.flight:
      return Icons.flight;
    case TransportMode.train:
      return Icons.train;
    case TransportMode.bus:
      return Icons.directions_bus;
    case TransportMode.car:
      return Icons.directions_car;
    case TransportMode.motorcycle:
      return Icons.motorcycle;
    case TransportMode.ferry:
      return Icons.directions_boat;
    case TransportMode.walk:
      return Icons.directions_walk;
    case TransportMode.other:
      return Icons.route;
  }
}

/// Renders the whole trip route (markers per waypoint + connecting lines per
/// segment), dispatching to whichever map engine [mapProviderConfigProvider]
/// currently selects. Callers never touch flutter_map or google_maps_flutter
/// directly.
///
/// Tap targets are markers only — flutter_map has no built-in polyline
/// hit-testing, so tapping the connecting line itself isn't supported.
class RouteMapView extends ConsumerWidget {
  const RouteMapView({
    required this.segments,
    required this.onSegmentTap,
    super.key,
  });

  final List<TripSegment> segments;
  final void Function(TripSegment segment) onSegmentTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (segments.isEmpty) {
      return const _EmptyRouteMap();
    }

    final provider = ref.watch(mapProviderConfigProvider);
    return switch (provider) {
      KumoMapProvider.openStreetMap =>
        _OsmRouteMap(segments: segments, onSegmentTap: onSegmentTap),
      KumoMapProvider.googleMaps =>
        _GoogleRouteMap(segments: segments, onSegmentTap: onSegmentTap),
    };
  }
}

class _EmptyRouteMap extends StatelessWidget {
  const _EmptyRouteMap();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Text(
            'Add a segment to see the route map',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
}

/// Bounding box covering the origin/destination of every segment, with a
/// small margin so edge markers aren't clipped by the viewport.
({double minLat, double maxLat, double minLng, double maxLng}) _bounds(
  List<TripSegment> segments,
) {
  final points = <Waypoint>[
    for (final s in segments) ...[s.origin, s.destination],
  ];
  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;
  for (final p in points) {
    minLat = p.latitude < minLat ? p.latitude : minLat;
    maxLat = p.latitude > maxLat ? p.latitude : maxLat;
    minLng = p.longitude < minLng ? p.longitude : minLng;
    maxLng = p.longitude > maxLng ? p.longitude : maxLng;
  }
  return (minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
}

class _OsmRouteMap extends StatelessWidget {
  const _OsmRouteMap({required this.segments, required this.onSegmentTap});

  final List<TripSegment> segments;
  final void Function(TripSegment segment) onSegmentTap;

  @override
  Widget build(BuildContext context) {
    final b = _bounds(segments);
    final bounds = fm.LatLngBounds(
      ll.LatLng(b.minLat, b.minLng),
      ll.LatLng(b.maxLat, b.maxLng),
    );

    return fm.FlutterMap(
      options: fm.MapOptions(
        initialCameraFit: fm.CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48),
        ),
      ),
      children: [
        fm.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.cygnus.travelKumo',
        ),
        fm.PolylineLayer(
          polylines: [
            for (final s in segments)
              fm.Polyline(
                points: [
                  ll.LatLng(s.origin.latitude, s.origin.longitude),
                  ll.LatLng(s.destination.latitude, s.destination.longitude),
                ],
                strokeWidth: 3,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
        fm.MarkerLayer(
          markers: [
            for (final s in segments)
              fm.Marker(
                point:
                    ll.LatLng(s.destination.latitude, s.destination.longitude),
                width: 40,
                height: 40,
                child: _SegmentMarker(
                  mode: s.mode,
                  onTap: () => onSegmentTap(s),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _GoogleRouteMap extends StatefulWidget {
  const _GoogleRouteMap({required this.segments, required this.onSegmentTap});

  final List<TripSegment> segments;
  final void Function(TripSegment segment) onSegmentTap;

  @override
  State<_GoogleRouteMap> createState() => _GoogleRouteMapState();
}

class _GoogleRouteMapState extends State<_GoogleRouteMap> {
  @override
  Widget build(BuildContext context) {
    final b = _bounds(widget.segments);
    final center = gm.LatLng(
      (b.minLat + b.maxLat) / 2,
      (b.minLng + b.maxLng) / 2,
    );

    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: center, zoom: 4),
      onMapCreated: (controller) {
        controller.animateCamera(
          gm.CameraUpdate.newLatLngBounds(
            gm.LatLngBounds(
              southwest: gm.LatLng(b.minLat, b.minLng),
              northeast: gm.LatLng(b.maxLat, b.maxLng),
            ),
            48,
          ),
        );
      },
      polylines: {
        for (final s in widget.segments)
          gm.Polyline(
            polylineId: gm.PolylineId(s.id),
            points: [
              gm.LatLng(s.origin.latitude, s.origin.longitude),
              gm.LatLng(s.destination.latitude, s.destination.longitude),
            ],
            width: 3,
            color: Theme.of(context).colorScheme.primary,
          ),
      },
      markers: {
        for (final s in widget.segments)
          gm.Marker(
            markerId: gm.MarkerId(s.id),
            position: gm.LatLng(s.destination.latitude, s.destination.longitude),
            infoWindow: gm.InfoWindow(title: s.destination.name),
            onTap: () => widget.onSegmentTap(s),
          ),
      },
    );
  }
}

class _SegmentMarker extends StatelessWidget {
  const _SegmentMarker({required this.mode, required this.onTap});

  final TransportMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: Icon(iconForTransportMode(mode), size: 20),
      ),
    );
  }
}
