import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart' as ll;

import '../../features/itinerary/domain/entities/transport_mode.dart';
import '../../features/itinerary/domain/entities/trip_segment.dart';
import '../../features/itinerary/domain/entities/waypoint.dart';
import 'kumo_map_provider.dart';
import 'route_curve.dart';
import 'route_line_painter.dart';
import 'route_marker_bitmaps.dart';
import 'route_path_sampling.dart';
import 'route_texture.dart';

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

// The mid-route mode icon (a Material glyph like a walking figure, a bus, a
// plane) is never rotated — most of these glyphs encode a real "up" (a
// person's head, a bus's roof) as well as a facing direction, so spinning
// the whole glyph to match bearing made it render upside-down for any
// southbound-ish segment, which read as broken rather than "pointing south".
// Direction of travel is instead shown by [_DirectionArrow]/
// [directionArrowBitmap], a small triangular badge that orbits the icon at
// the segment's bearing — a plain triangle has no "correct" orientation, so
// it never looks wrong at any rotation.
const _modeMarkerBoxSize = 48.0;
const _modeMarkerIconSize = 34.0;

// Rail gap for a doubleTread (car/bus) segment's two wheel-track polylines,
// as a fraction of the segment's own path length — see offsetPath's doc for
// why this is geometry-based rather than a fixed real-world gauge. Shared
// between _addPolylinesForSegment (draws the rails) and the Google engine's
// tick-placement loop (samples the car-tread bitmap along the same rails)
// so they can't drift out of sync. 0.018 * 7/4 to match the OSM engine's
// rail offset (see the RouteTexture.doubleTread case in
// route_line_painter.dart's paintRouteTexture) now that the ported
// car-tread module needs more room between the two tracks than the old
// single-chevron rendering did.
const _doubleTreadHalfGapFraction = 0.0315;

/// The lat/lng path drawn for [segment] — the real routed road/footpath if
/// one has been fetched and cached (`RoutingService`, see
/// `lib/features/itinerary/presentation/providers/trip_segment_provider.dart`),
/// otherwise curved if some other segment in [all] covers the same two
/// waypoints in the opposite direction, otherwise a straight line. Shared by
/// both map engines and the OSM texture layer so they all draw the exact
/// same geometry.
///
/// A real routed out-and-back pair can still overlap itself on a one-road
/// round trip — the "bow apart" trick below only applies to the synthetic
/// fallback line, not real route geometry. Accepted trade-off, not fixed
/// here.
List<(double, double)> _geoPath(TripSegment segment, List<TripSegment> all) {
  final routed = segment.routeGeometry;
  if (routed != null && routed.length >= 2) {
    return routed;
  }
  return curvedPath(
    startLat: segment.origin.latitude,
    startLng: segment.origin.longitude,
    endLat: segment.destination.latitude,
    endLng: segment.destination.longitude,
    curved: hasReverseLeg(all, segment),
  );
}

/// Renders the whole trip route (a destination pin + city label per leg, a
/// mode-texture line, and an upright transport-mode icon with a rotating
/// direction-arrow badge at each leg's midpoint), dispatching to whichever
/// map engine [mapProviderConfigProvider]
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
      KumoMapProvider.openStreetMap => _OsmRouteMap(
        segments: segments,
        onSegmentTap: onSegmentTap,
      ),
      KumoMapProvider.googleMaps => _GoogleRouteMap(
        segments: segments,
        onSegmentTap: onSegmentTap,
      ),
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
    final colorScheme = Theme.of(context).colorScheme;

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
        _RouteTextureLayer(segments: segments, color: colorScheme.primary),
        fm.MarkerLayer(
          markers: [
            for (final s in segments) ...[
              () {
                final mid = pointAtFraction(_geoPath(s, segments), 0.5);
                return fm.Marker(
                  point: ll.LatLng(mid.lat, mid.lng),
                  width: _modeMarkerBoxSize,
                  height: _modeMarkerBoxSize,
                  child: _ModeIconMarker(
                    mode: s.mode,
                    bearingDegrees: mid.bearingDegrees,
                    onTap: () => onSegmentTap(s),
                  ),
                );
              }(),
              fm.Marker(
                point: ll.LatLng(
                  s.destination.latitude,
                  s.destination.longitude,
                ),
                width: 124,
                height: 66,
                alignment: Alignment.bottomCenter,
                child: _DestinationPin(
                  cityName: s.destination.name,
                  onTap: () => onSegmentTap(s),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Draws every segment's mode-texture route line (see route_texture.dart /
/// route_line_painter.dart) directly in screen space, so tread/tie/chevron
/// marks stay a constant pixel size regardless of zoom.
class _RouteTextureLayer extends StatelessWidget {
  const _RouteTextureLayer({required this.segments, required this.color});

  final List<TripSegment> segments;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final camera = fm.MapCamera.of(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _RouteTexturePainter(
          segments: segments,
          camera: camera,
          color: color,
        ),
      ),
    );
  }
}

class _RouteTexturePainter extends CustomPainter {
  _RouteTexturePainter({
    required this.segments,
    required this.camera,
    required this.color,
  });

  final List<TripSegment> segments;
  final fm.MapCamera camera;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in segments) {
      final screenPath = [
        for (final (lat, lng) in _geoPath(s, segments))
          _projectToScreen(camera, lat, lng),
      ];
      paintRouteTexture(
        canvas: canvas,
        path: screenPath,
        mode: s.mode,
        color: color,
      );
    }
  }

  // Repainting is driven entirely by rebuilds (this widget only rebuilds
  // when MapCamera.of(context) reports a change), so a fresh instance always
  // means "camera or segments changed" — cheap enough at this app's segment
  // counts (a handful to a few dozen per trip) to just always repaint.
  @override
  bool shouldRepaint(covariant _RouteTexturePainter oldDelegate) => true;
}

Offset _projectToScreen(fm.MapCamera camera, double lat, double lng) {
  final point = camera.latLngToScreenPoint(ll.LatLng(lat, lng));
  return Offset(point.x, point.y);
}

class _ModeIconMarker extends StatelessWidget {
  const _ModeIconMarker({
    required this.mode,
    required this.bearingDegrees,
    required this.onTap,
  });

  final TransportMode mode;
  final double bearingDegrees;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _modeMarkerBoxSize,
      height: _modeMarkerBoxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Transform.rotate(
              angle: bearingDegrees * pi / 180,
              child: SizedBox(
                width: _modeMarkerBoxSize,
                height: _modeMarkerBoxSize,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _DirectionArrow(
                    color: colorScheme.surface,
                    outlineColor: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: _modeMarkerIconSize,
              height: _modeMarkerIconSize,
              child: CircleAvatar(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                child: Icon(iconForTransportMode(mode), size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small triangular badge that always points "up" in its own artwork, then
/// gets rotated (by the caller) to the segment's bearing — unlike the mode
/// icon glyph, a plain triangle has no head/roof/fuselage baked into it, so
/// it reads correctly at any rotation instead of flipping upside-down.
class _DirectionArrow extends StatelessWidget {
  const _DirectionArrow({required this.color, required this.outlineColor});

  final Color color;
  final Color outlineColor;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(14, 12),
    painter: _DirectionArrowPainter(color: color, outlineColor: outlineColor),
  );
}

class _DirectionArrowPainter extends CustomPainter {
  _DirectionArrowPainter({required this.color, required this.outlineColor});

  final Color color;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = outlineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DirectionArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.outlineColor != outlineColor;
}

class _DestinationPin extends StatelessWidget {
  const _DestinationPin({required this.cityName, required this.onTap});

  final String cityName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 108),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                cityName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Icon(Icons.location_on, color: colorScheme.primary, size: 34),
        ],
      ),
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

class _RouteBitmaps {
  _RouteBitmaps({
    required this.destinationPins,
    required this.modeIcons,
    required this.tickIcons,
    required this.directionArrow,
  });

  final Map<String, gm.BitmapDescriptor> destinationPins;
  final Map<TransportMode, gm.BitmapDescriptor> modeIcons;
  final Map<RouteTexture, gm.BitmapDescriptor?> tickIcons;
  final gm.BitmapDescriptor directionArrow;
}

Future<_RouteBitmaps> _loadRouteBitmaps(
  List<TripSegment> segments,
  ColorScheme colorScheme,
) async {
  final destinationPins = <String, gm.BitmapDescriptor>{};
  for (final s in segments) {
    destinationPins[s.id] = await destinationPinBitmap(
      cityName: s.destination.name,
      pinColor: colorScheme.primary,
      labelBackground: colorScheme.surfaceContainerHighest,
      labelTextColor: colorScheme.onSurface,
    );
  }

  final modeIcons = <TransportMode, gm.BitmapDescriptor>{};
  for (final mode in segments.map((s) => s.mode).toSet()) {
    modeIcons[mode] = await modeIconBitmap(
      icon: iconForTransportMode(mode),
      background: colorScheme.primary,
      foreground: colorScheme.onPrimary,
    );
  }

  final tickIcons = <RouteTexture, gm.BitmapDescriptor?>{};
  for (final texture in modeIcons.keys.map(textureForMode).toSet()) {
    final future = textureTickBitmap(
      texture: texture,
      color: colorScheme.primary,
    );
    tickIcons[texture] = future == null ? null : await future;
  }

  final directionArrow = await directionArrowBitmap(
    color: colorScheme.surface,
    outlineColor: colorScheme.primary,
  );

  return _RouteBitmaps(
    destinationPins: destinationPins,
    modeIcons: modeIcons,
    tickIcons: tickIcons,
    directionArrow: directionArrow,
  );
}

String _bitmapCacheKey(List<TripSegment> segments, ColorScheme colorScheme) {
  final buffer = StringBuffer()
    ..write(colorScheme.primary)
    ..write('|')
    ..write(colorScheme.onPrimary)
    ..write('|')
    ..write(colorScheme.surfaceContainerHighest)
    ..write('|')
    ..write(colorScheme.onSurface);
  for (final s in segments) {
    buffer
      ..write('|')
      ..write(s.id)
      ..write(':')
      ..write(s.mode.name)
      ..write(':')
      ..write(s.destination.name);
  }
  return buffer.toString();
}

class _GoogleRouteMapState extends State<_GoogleRouteMap> {
  late Future<_RouteBitmaps> _bitmapsFuture;
  String? _bitmapsKey;

  Future<_RouteBitmaps> _ensureBitmaps(ColorScheme colorScheme) {
    final key = _bitmapCacheKey(widget.segments, colorScheme);
    if (key != _bitmapsKey) {
      _bitmapsKey = key;
      _bitmapsFuture = _loadRouteBitmaps(widget.segments, colorScheme);
    }
    return _bitmapsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<_RouteBitmaps>(
      future: _ensureBitmaps(colorScheme),
      builder: (context, snapshot) => _buildMap(colorScheme, snapshot.data),
    );
  }

  Widget _buildMap(ColorScheme colorScheme, _RouteBitmaps? bitmaps) {
    final b = _bounds(widget.segments);
    final center = gm.LatLng(
      (b.minLat + b.maxLat) / 2,
      (b.minLng + b.maxLng) / 2,
    );

    final polylines = <gm.Polyline>{};
    final markers = <gm.Marker>{};

    for (final s in widget.segments) {
      final geoPath = _geoPath(s, widget.segments);
      final texture = textureForMode(s.mode);
      _addPolylinesForSegment(polylines, s, geoPath, texture, colorScheme);

      final tickBitmap = bitmaps?.tickIcons[texture];
      if (tickBitmap != null) {
        final tickCount = tickCountForTexture(texture);
        if (texture == RouteTexture.doubleTread) {
          // Car/bus tread blocks belong on a wheel track, not the path
          // centreline — sample the same bitmap along both offset rails
          // (the ones _addPolylinesForSegment draws) so each track carries
          // the pattern, matching the OSM engine's per-rail rendering.
          final halfGap = pathLength(geoPath) * _doubleTreadHalfGapFraction;
          for (var rail = 0; rail < 2; rail++) {
            final railOffset = rail == 0 ? halfGap : -halfGap;
            final railTicks = sampleEvenly(
              offsetPath(geoPath, railOffset),
              tickCount,
            );
            for (var i = 0; i < railTicks.length; i++) {
              final tick = railTicks[i];
              markers.add(
                gm.Marker(
                  markerId: gm.MarkerId('${s.id}-tick-$rail-$i'),
                  position: gm.LatLng(tick.lat, tick.lng),
                  icon: tickBitmap,
                  rotation: tick.bearingDegrees,
                  anchor: const Offset(0.5, 0.5),
                  zIndexInt: 1,
                ),
              );
            }
          }
        } else {
          final ticks = sampleEvenly(geoPath, tickCount);
          for (var i = 0; i < ticks.length; i++) {
            final tick = ticks[i];
            markers.add(
              gm.Marker(
                markerId: gm.MarkerId('${s.id}-tick-$i'),
                position: gm.LatLng(tick.lat, tick.lng),
                icon: tickBitmap,
                rotation: tick.bearingDegrees,
                anchor: const Offset(0.5, 0.5),
                zIndexInt: 1,
              ),
            );
          }
        }
      }

      final modeIcon = bitmaps?.modeIcons[s.mode];
      if (modeIcon != null) {
        final mid = pointAtFraction(geoPath, 0.5);
        markers
          ..add(
            gm.Marker(
              markerId: gm.MarkerId('${s.id}-mode-arrow'),
              position: gm.LatLng(mid.lat, mid.lng),
              icon: bitmaps!.directionArrow,
              rotation: mid.bearingDegrees,
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 2,
            ),
          )
          ..add(
            gm.Marker(
              markerId: gm.MarkerId('${s.id}-mode'),
              position: gm.LatLng(mid.lat, mid.lng),
              icon: modeIcon,
              anchor: const Offset(0.5, 0.5),
              onTap: () => widget.onSegmentTap(s),
              zIndexInt: 3,
            ),
          );
      }

      markers.add(
        gm.Marker(
          markerId: gm.MarkerId(s.id),
          position: gm.LatLng(s.destination.latitude, s.destination.longitude),
          icon:
              bitmaps?.destinationPins[s.id] ??
              gm.BitmapDescriptor.defaultMarker,
          onTap: () => widget.onSegmentTap(s),
          zIndexInt: 4,
        ),
      );
    }

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
      polylines: polylines,
      markers: markers,
    );
  }

  void _addPolylinesForSegment(
    Set<gm.Polyline> polylines,
    TripSegment s,
    List<(double, double)> geoPath,
    RouteTexture texture,
    ColorScheme colorScheme,
  ) {
    gm.Polyline line(
      String suffix,
      List<(double, double)> path, {
      required double width,
      required Color color,
      List<gm.PatternItem> patterns = const [],
    }) => gm.Polyline(
      polylineId: gm.PolylineId('${s.id}-$suffix'),
      points: [for (final (lat, lng) in path) gm.LatLng(lat, lng)],
      width: width.round(),
      color: color,
      patterns: patterns,
    );

    switch (texture) {
      case RouteTexture.dashedLine:
        polylines.add(
          line(
            'line',
            geoPath,
            width: 3,
            color: colorScheme.primary,
            patterns: [gm.PatternItem.dash(24), gm.PatternItem.gap(14)],
          ),
        );

      case RouteTexture.footsteps:
        break; // Footsteps replace the line entirely — see OSM's painter.

      case RouteTexture.singleTread:
        polylines.add(
          line('line', geoPath, width: 3, color: colorScheme.primary),
        );

      case RouteTexture.doubleTread:
      case RouteTexture.trainTrack:
        final fraction = texture == RouteTexture.trainTrack
            ? 0.025
            : _doubleTreadHalfGapFraction;
        final halfGap = pathLength(geoPath) * fraction;
        polylines
          ..add(
            line(
              'rail-a',
              offsetPath(geoPath, halfGap),
              width: 2,
              color: colorScheme.primary,
            ),
          )
          ..add(
            line(
              'rail-b',
              offsetPath(geoPath, -halfGap),
              width: 2,
              color: colorScheme.primary,
            ),
          );
    }
  }
}
