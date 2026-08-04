import 'dart:math';
import 'dart:ui';

import '../../features/itinerary/domain/entities/transport_mode.dart';
import 'route_texture.dart';

/// Screen-space drawing for a segment's route line + mode texture, used by
/// the OpenStreetMap engine's custom overlay layer (see
/// `_RouteTextureLayer` in route_map_view.dart).
///
/// Everything here works in already-projected [Offset] screen points rather
/// than lat/lng, so it's zoom-independent (a fixed pixel width regardless of
/// scale, unlike a lat/lng offset which would be geographically-accurate but
/// either invisible or absurdly wide at map zoom levels) and automatically
/// correct under map rotation (the local tangent is derived straight from
/// consecutive screen points, not from compass bearing).
typedef _Sample = ({Offset point, Offset tangent});

double _pathLengthPx(List<Offset> path) {
  var total = 0.0;
  for (var i = 0; i < path.length - 1; i++) {
    total += (path[i + 1] - path[i]).distance;
  }
  return total;
}

_Sample _sampleAt(List<Offset> path, double distance) {
  var walked = 0.0;
  for (var i = 0; i < path.length - 1; i++) {
    final a = path[i];
    final b = path[i + 1];
    final segLength = (b - a).distance;
    if (segLength == 0) continue;
    if (walked + segLength >= distance || i == path.length - 2) {
      final t = ((distance - walked) / segLength).clamp(0.0, 1.0);
      return (point: Offset.lerp(a, b, t)!, tangent: (b - a) / segLength);
    }
    walked += segLength;
  }
  final a = path[path.length - 2];
  final b = path.last;
  final segLength = (b - a).distance;
  return (
    point: b,
    tangent: segLength == 0 ? const Offset(1, 0) : (b - a) / segLength,
  );
}

List<_Sample> _sampleEvenly(List<Offset> path, int count) {
  if (count <= 0 || path.length < 2) return const [];
  final total = _pathLengthPx(path);
  if (total == 0) return const [];
  return [
    for (var i = 0; i < count; i++) _sampleAt(path, total * (i + 0.5) / count),
  ];
}

// The car-tread module's own along-travel extent is ~4.4px (see
// _drawCarTreadBlocks), and assets/icons/car_tyre_tread.svg tiles it with
// next to no gap — a real tyre's tread blocks run almost edge to edge. A
// fixed tick *count* over the whole segment (as most other textures use,
// deliberately, for stylised zoom-independence — see tickCountForTexture's
// doc) can't reproduce that: a long or heavily-zoomed segment just spreads
// the same handful of blocks thin. This spaces them at a constant *pixel*
// interval instead, so the density always reads as one continuous tread
// regardless of the segment's on-screen length. 3.6 (down from an initial
// 9) so consecutive modules run close to edge-to-edge, matching the SVG.
const _carTreadPeriodPx = 3.6;

int _carTreadTickCount(List<Offset> path) =>
    max(4, (_pathLengthPx(path) / _carTreadPeriodPx).round());

// Same reasoning as _carTreadPeriodPx, for the moto-tread module (own
// along-travel extent ~7.2px — see _drawMotoTreadBlocks): a fixed tick
// count over the whole segment spread the blocks too far apart on anything
// but a short segment, so this spaces them at a constant pixel interval
// instead.
const _motoTreadPeriodPx = 6.0;

int _motoTreadTickCount(List<Offset> path) =>
    max(4, (_pathLengthPx(path) / _motoTreadPeriodPx).round());

// Same reasoning again, for a footprint pair (own along-travel extent
// ~10.6px — see _drawFootsteps, toe oval + heel oval).
const _footstepsPeriodPx = 9.0;

int _footstepsTickCount(List<Offset> path) =>
    max(4, (_pathLengthPx(path) / _footstepsPeriodPx).round());

// Same reasoning again, for a sleeper tick. Unlike the tread modules above,
// a sleeper has no filled along-travel extent of its own (it's a thin
// perpendicular line), so this period is chosen directly for a railway-tie
// look — evenly spaced, individually distinguishable — rather than derived
// from a shape's own bounding box.
const _trainTrackPeriodPx = 10.0;

int _trainTrackTickCount(List<Offset> path) =>
    max(4, (_pathLengthPx(path) / _trainTrackPeriodPx).round());

Offset _perp(Offset tangent) => Offset(-tangent.dy, tangent.dx);

List<Offset> _offsetPath(List<Offset> path, double amount) => [
  for (var i = 0; i < path.length; i++)
    () {
      final prev = path[max(0, i - 1)];
      final next = path[min(path.length - 1, i + 1)];
      final dir = next - prev;
      final len = dir.distance;
      final tangent = len == 0 ? const Offset(1, 0) : dir / len;
      return path[i] + _perp(tangent) * amount;
    }(),
];

void _drawPolyline(Canvas canvas, List<Offset> path, Paint paint) {
  final p = Path()..moveTo(path.first.dx, path.first.dy);
  for (final pt in path.skip(1)) {
    p.lineTo(pt.dx, pt.dy);
  }
  canvas.drawPath(p, paint);
}

void _drawDashed(
  Canvas canvas,
  List<Offset> path,
  Paint paint, {
  required double dash,
  required double gap,
}) {
  var remaining = dash;
  var drawing = true;
  for (var i = 0; i < path.length - 1; i++) {
    var a = path[i];
    final b = path[i + 1];
    var segLength = (b - a).distance;
    if (segLength == 0) continue;
    final dir = (b - a) / segLength;
    while (segLength > 0) {
      final step = min(remaining, segLength);
      final next = a + dir * step;
      if (drawing) canvas.drawLine(a, next, paint);
      a = next;
      segLength -= step;
      remaining -= step;
      if (remaining <= 0) {
        drawing = !drawing;
        remaining = drawing ? dash : gap;
      }
    }
  }
}

void _drawPerpendicularTicks(
  Canvas canvas,
  List<_Sample> samples,
  Paint paint, {
  required double halfLength,
}) {
  for (final s in samples) {
    final perp = _perp(s.tangent);
    canvas.drawLine(
      s.point + perp * halfLength,
      s.point - perp * halfLength,
      paint,
    );
  }
}

void _fillPolygon(Canvas canvas, Paint paint, List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path..close(), paint);
}

/// Draws one repeat of `assets/icons/motorcycle_tyre_tread.svg`'s tread
/// module at each sample point: this is that SVG's own `<path>` coordinates
/// for the left/right asymmetric siping blocks and the two corner
/// stabilizing lugs, recentred on the pattern tile's midpoint (40, 20) and
/// scaled by 0.18 (each block keeps its original cubic-bezier curve via
/// [Path.cubicTo], not a straight-line stand-in). The SVG's continuous
/// central rib isn't repeated here — it tiles into one unbroken bar, which
/// is exactly what the caller's plain polyline underneath already is.
void _drawMotoTreadBlocks(Canvas canvas, List<_Sample> samples, Paint paint) {
  for (final s in samples) {
    final angle = atan2(s.tangent.dy, s.tangent.dx) - pi / 2;
    canvas.save();
    canvas.translate(s.point.dx, s.point.dy);
    canvas.rotate(angle);
    // Local frame: +y is the travel direction (see _drawFootsteps).
    canvas.drawPath(
      Path()
        ..moveTo(-3.24, -3.24)
        ..lineTo(-1.44, -0.9)
        ..cubicTo(-1.44, 0.36, -2.16, 1.08, -3.24, 1.08)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(3.24, -0.72)
        ..lineTo(1.44, 1.62)
        ..cubicTo(1.44, 2.88, 2.16, 3.6, 3.24, 3.6)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-5.04, 2.16)
        ..lineTo(-3.6, 3.24)
        ..lineTo(-5.04, 3.24)
        ..cubicTo(-5.4, 3.24, -5.76, 2.88, -5.76, 2.52)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(5.04, -3.6)
        ..lineTo(3.6, -2.52)
        ..lineTo(5.04, -2.52)
        ..cubicTo(5.4, -2.52, 5.76, -2.16, 5.76, -1.8)
        ..close(),
      paint,
    );
    canvas.restore();
  }
}

/// Draws one repeat of `assets/icons/car_tyre_tread.svg`'s tread module on
/// a single wheel track, at [railOffset] from the path centreline: this is
/// the SVG's own left/right shoulder-block and V-groove-chevron `<path>`
/// data plus its two centre-strip `<rect>`s — the whole tile, not a
/// stripped-down stand-in — recentred on the pattern tile's midpoint
/// (50, 20), scaled by 0.12, then further squeezed to 70% on the cross-axis
/// (x) only — a narrower tread than the rail gauge it sits on, rather than
/// scaling the whole module (which would've pulled the tracks themselves
/// closer together too). [railOffset] — the rail gauge — is unrelated and
/// stays whatever the caller passes. The caller applies this once per rail
/// (`±railOffset`) so both wheel tracks carry the full pattern — the
/// "double trace" look, replacing the single chevron spanning both rails
/// that the old rendering used.
void _drawCarTreadBlocks(
  Canvas canvas,
  List<_Sample> samples,
  Paint paint, {
  required double railOffset,
}) {
  for (final s in samples) {
    final perp = _perp(s.tangent);
    final railCenter = s.point + perp * railOffset;
    final angle = atan2(s.tangent.dy, s.tangent.dx) - pi / 2;
    canvas.save();
    canvas.translate(railCenter.dx, railCenter.dy);
    canvas.rotate(angle);
    // Local frame: +y is the travel direction (see _drawFootsteps).
    _fillPolygon(canvas, paint, const [
      Offset(-3.78, -1.8),
      Offset(-2.352, -1.8),
      Offset(-2.52, -0.24),
      Offset(-3.78, -0.24),
    ]);
    _fillPolygon(canvas, paint, const [
      Offset(-3.78, 0.24),
      Offset(-2.52, 0.24),
      Offset(-2.352, 1.8),
      Offset(-3.78, 1.8),
    ]);
    _fillPolygon(canvas, paint, const [
      Offset(3.78, -1.8),
      Offset(2.352, -1.8),
      Offset(2.52, -0.24),
      Offset(3.78, -0.24),
    ]);
    _fillPolygon(canvas, paint, const [
      Offset(3.78, 0.24),
      Offset(2.52, 0.24),
      Offset(2.352, 1.8),
      Offset(3.78, 1.8),
    ]);
    _fillPolygon(canvas, paint, const [
      Offset(-1.848, -1.68),
      Offset(-0.504, -0.6),
      Offset(-0.504, 0.24),
      Offset(-1.848, -0.84),
    ]);
    _fillPolygon(canvas, paint, const [
      Offset(-1.848, 0.36),
      Offset(-0.504, 1.44),
      Offset(-0.504, 2.28),
      Offset(-1.848, 1.2),
    ]);
    _fillPolygon(canvas, paint, const [
      Offset(1.848, -1.68),
      Offset(0.504, -0.6),
      Offset(0.504, 0.24),
      Offset(1.848, -0.84),
    ]);
    _fillPolygon(canvas, paint, const [
      Offset(1.848, 0.36),
      Offset(0.504, 1.44),
      Offset(0.504, 2.28),
      Offset(1.848, 1.2),
    ]);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(-0.21, -2.16, 0.21, -0.36),
        const Radius.circular(0.084),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(-0.21, 0.24, 0.21, 2.04),
        const Radius.circular(0.084),
      ),
      paint,
    );
    canvas.restore();
  }
}

void _drawFootsteps(Canvas canvas, List<_Sample> samples, Paint paint) {
  for (var i = 0; i < samples.length; i++) {
    final s = samples[i];
    final angle = atan2(s.tangent.dy, s.tangent.dx) - pi / 2;
    final side = i.isEven ? 1.0 : -1.0;
    final center = s.point + _perp(s.tangent) * (3.5 * side);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    // Local frame: +y is the travel direction, so the toes (drawn further
    // along +y) point the way the traveller is walking.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 2.2), width: 4.4, height: 6.2),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -3.4), width: 3.4, height: 3.8),
      paint,
    );
    canvas.restore();
  }
}

/// Draws [path] (already projected to screen [Offset]s) styled for [mode],
/// in [color].
void paintRouteTexture({
  required Canvas canvas,
  required List<Offset> path,
  required TransportMode mode,
  required Color color,
}) {
  if (path.length < 2) return;
  final texture = textureForMode(mode);

  switch (texture) {
    case RouteTexture.dashedLine:
      _drawDashed(
        canvas,
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
        dash: 12,
        gap: 8,
      );

    case RouteTexture.footsteps:
      // Footsteps replace the line entirely for walking legs (no base
      // polyline underneath), per the "footsteps instead of a line" spec.
      _drawFootsteps(
        canvas,
        _sampleEvenly(path, _footstepsTickCount(path)),
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

    case RouteTexture.singleTread:
      _drawPolyline(
        canvas,
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      _drawMotoTreadBlocks(
        canvas,
        _sampleEvenly(path, _motoTreadTickCount(path)),
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

    case RouteTexture.doubleTread:
      final railPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      // Rail gauge (7) is independent of the tread module's own width —
      // see _drawCarTreadBlocks — so narrowing the tread doesn't pull the
      // two wheel tracks closer together.
      _drawPolyline(canvas, _offsetPath(path, 7), railPaint);
      _drawPolyline(canvas, _offsetPath(path, -7), railPaint);
      final blockPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final blockSamples = _sampleEvenly(path, _carTreadTickCount(path));
      _drawCarTreadBlocks(canvas, blockSamples, blockPaint, railOffset: 7);
      _drawCarTreadBlocks(canvas, blockSamples, blockPaint, railOffset: -7);

    case RouteTexture.trainTrack:
      final railPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      _drawPolyline(canvas, _offsetPath(path, 4.5), railPaint);
      _drawPolyline(canvas, _offsetPath(path, -4.5), railPaint);
      _drawPerpendicularTicks(
        canvas,
        _sampleEvenly(path, _trainTrackTickCount(path)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
        halfLength: 7,
      );
  }
}
