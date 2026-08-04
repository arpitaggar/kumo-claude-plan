import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

import 'route_texture.dart';

/// Rasterises small marker icons for the Google Maps engine using
/// [dart:ui] `Canvas`/`TextPainter` directly rather than capturing a real
/// widget tree — `google_maps_flutter` markers need PNG bytes
/// ([gm.BitmapDescriptor.bytes]), and Material icons are drawable straight
/// from their glyph (`IconData.codePoint`) in the `MaterialIcons` font
/// without mounting any widgets off-screen.
///
/// All shapes here are drawn "forward-facing up" (unrotated) — direction is
/// applied afterwards via `gm.Marker.rotation` (degrees clockwise from
/// north), which Google Maps applies to non-flat marker icons regardless of
/// camera bearing.
const _pixelRatio = 3.0;

Future<gm.BitmapDescriptor> _render(
  void Function(Canvas canvas) draw, {
  required double width,
  required double height,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, width * _pixelRatio, height * _pixelRatio),
  );
  canvas.scale(_pixelRatio);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (width * _pixelRatio).round(),
    (height * _pixelRatio).round(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return gm.BitmapDescriptor.bytes(
    byteData!.buffer.asUint8List(),
    imagePixelRatio: _pixelRatio,
  );
}

TextPainter _glyphPainter(IconData icon, double size, Color color) =>
    TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

/// A pin (the `location_on` glyph) with [cityName] in a pill label above
/// it. The bitmap's bottom-centre — where [gm.Marker.anchor] should be set
/// to `Offset(0.5, 1.0)` — lands on the pin's tip.
Future<gm.BitmapDescriptor> destinationPinBitmap({
  required String cityName,
  required Color pinColor,
  required Color labelBackground,
  required Color labelTextColor,
}) async {
  const pinSize = 34.0;
  const labelPadH = 8.0;
  const labelPadV = 3.0;
  const gap = 2.0;

  final text = TextPainter(
    text: TextSpan(
      text: cityName,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: labelTextColor,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: 150);

  final labelWidth = text.width + labelPadH * 2;
  final labelHeight = text.height + labelPadV * 2;
  final width = max(labelWidth, pinSize) + 4;
  final height = labelHeight + gap + pinSize;
  final centerX = width / 2;

  final pin = _glyphPainter(Icons.location_on, pinSize, pinColor);

  return _render(
    (canvas) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(centerX, labelHeight / 2),
            width: labelWidth,
            height: labelHeight,
          ),
          Radius.circular(labelHeight / 2),
        ),
        Paint()..color = labelBackground,
      );
      text.paint(
        canvas,
        Offset(centerX - text.width / 2, (labelHeight - text.height) / 2),
      );
      pin.paint(canvas, Offset(centerX - pin.width / 2, labelHeight + gap));
    },
    width: width,
    height: height,
  );
}

/// The transport-mode icon on a filled circle backdrop, for the marker
/// placed at a segment's route midpoint (see `_ModeIconMarker` /
/// `_GoogleRouteMap` in route_map_view.dart). Unrotated; the caller sets
/// [gm.Marker.rotation] to the segment's local bearing.
Future<gm.BitmapDescriptor> modeIconBitmap({
  required IconData icon,
  required Color background,
  required Color foreground,
}) async {
  const size = 34.0;
  final glyph = _glyphPainter(icon, 20, foreground);
  return _render(
    (canvas) {
      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2,
        Paint()..color = background,
      );
      glyph.paint(
        canvas,
        Offset(size / 2 - glyph.width / 2, size / 2 - glyph.height / 2),
      );
    },
    width: size,
    height: size,
  );
}

/// A small triangular arrow badge indicating a segment's travel direction,
/// for use alongside [modeIconBitmap] (see `_ModeIconMarker` /
/// `_GoogleRouteMap` in route_map_view.dart). Unlike the mode icon, this
/// glyph is placed at the same position as the mode icon but on its own
/// marker, drawn near the top edge of a canvas centred on
/// [gm.Marker.anchor] `(0.5, 0.5)` — so setting [gm.Marker.rotation] to the
/// segment's bearing sweeps the arrow around the (unrotated) mode icon
/// rather than spinning an asymmetric glyph in place, which is what made
/// glyphs like a walking figure or a bus render upside-down for
/// southbound-ish segments.
Future<gm.BitmapDescriptor> directionArrowBitmap({
  required Color color,
  required Color outlineColor,
}) {
  const size = 48.0;
  const arrowWidth = 14.0;
  const arrowHeight = 12.0;
  final left = size / 2 - arrowWidth / 2;
  final path = Path()
    ..moveTo(size / 2, 0)
    ..lineTo(left + arrowWidth, arrowHeight)
    ..lineTo(left, arrowHeight)
    ..close();

  return _render(
    (canvas) {
      canvas.drawPath(
        path,
        Paint()
          ..color = outlineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(path, Paint()..color = color);
    },
    width: size,
    height: size,
  );
}

/// A single texture-tick icon for [texture], drawn pointing "up" (towards
/// travel direction under a rotation of 0). Ticks are placed at fixed
/// fractional positions along a segment's path rather than at a constant
/// pixel spacing — see `offsetPath` in route_path_sampling.dart for why
/// Google Maps can't match the OSM engine's zoom-independent rendering.
Future<gm.BitmapDescriptor>? textureTickBitmap({
  required RouteTexture texture,
  required Color color,
}) {
  const size = 16.0;
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;

  switch (texture) {
    case RouteTexture.dashedLine:
      return null; // Handled entirely via Polyline dash patterns.

    case RouteTexture.footsteps:
      return _render(
        (canvas) {
          canvas.drawOval(
            Rect.fromCenter(
              center: const Offset(size / 2, size * 0.62),
              width: size * 0.4,
              height: size * 0.42,
            ),
            Paint()..color = color,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: const Offset(size / 2, size * 0.28),
              width: size * 0.3,
              height: size * 0.3,
            ),
            Paint()..color = color,
          );
        },
        width: size,
        height: size,
      );

    case RouteTexture.singleTread:
      // This is assets/icons/motorcycle_tyre_tread.svg's own left/right
      // block and corner-lug <path> coordinates (cubic beziers included,
      // via Path.cubicTo — not straight-line stand-ins), recentred and
      // scaled the same way as _drawMotoTreadBlocks in
      // route_line_painter.dart, then flipped from that file's "+y forward"
      // frame to this function's "up (-y) is forward" bitmap convention.
      // Drawn on its own larger canvas since the block detail doesn't fit
      // the other textures' plain 16x16 tick tile. The SVG's continuous
      // rib isn't repeated here — the caller already draws a continuous
      // Polyline underneath (see the RouteTexture.singleTread branch in
      // _addPolylinesForSegment).
      return _render(
        (canvas) {
          final fillPaint = Paint()..color = color;
          canvas.drawPath(
            Path()
              ..moveTo(3.76, 7.74)
              ..lineTo(5.56, 5.4)
              ..cubicTo(5.56, 4.14, 4.84, 3.42, 3.76, 3.42)
              ..close(),
            fillPaint,
          );
          canvas.drawPath(
            Path()
              ..moveTo(10.24, 5.22)
              ..lineTo(8.44, 2.88)
              ..cubicTo(8.44, 1.62, 9.16, 0.9, 10.24, 0.9)
              ..close(),
            fillPaint,
          );
          canvas.drawPath(
            Path()
              ..moveTo(1.96, 2.34)
              ..lineTo(3.4, 1.26)
              ..lineTo(1.96, 1.26)
              ..cubicTo(1.6, 1.26, 1.24, 1.62, 1.24, 1.98)
              ..close(),
            fillPaint,
          );
          canvas.drawPath(
            Path()
              ..moveTo(12.04, 8.1)
              ..lineTo(10.6, 7.02)
              ..lineTo(12.04, 7.02)
              ..cubicTo(12.4, 7.02, 12.76, 6.66, 12.76, 6.3)
              ..close(),
            fillPaint,
          );
        },
        width: 14,
        height: 9,
      );

    case RouteTexture.doubleTread:
      // This is assets/icons/car_tyre_tread.svg's own shoulder-block,
      // V-groove-chevron and centre-strip <path>/<rect> coordinates — the
      // whole tile, not a stripped-down stand-in — recentred and scaled
      // the same way as _drawCarTreadBlocks in route_line_painter.dart
      // (including that function's further 70%-on-the-cross-axis-only
      // squeeze, narrowing the tread without narrowing the rail gauge it
      // sits on), then flipped to this function's "up (-y) is forward"
      // bitmap convention. The caller places this once per wheel track —
      // sampled along both offset rails rather than the path centreline,
      // see the doubleTread branch in route_map_view.dart's tick-placement
      // loop — so both tracks carry the full pattern (the "double trace"
      // look).
      return _render(
        (canvas) {
          final fillPaint = Paint()..color = color;
          void block(List<Offset> points) {
            final path = Path()..moveTo(points.first.dx, points.first.dy);
            for (final p in points.skip(1)) {
              path.lineTo(p.dx, p.dy);
            }
            canvas.drawPath(path..close(), fillPaint);
          }

          block(const [
            Offset(3.22, 5.8),
            Offset(4.648, 5.8),
            Offset(4.48, 4.24),
            Offset(3.22, 4.24),
          ]);
          block(const [
            Offset(3.22, 3.76),
            Offset(4.48, 3.76),
            Offset(4.648, 2.2),
            Offset(3.22, 2.2),
          ]);
          block(const [
            Offset(10.78, 5.8),
            Offset(9.352, 5.8),
            Offset(9.52, 4.24),
            Offset(10.78, 4.24),
          ]);
          block(const [
            Offset(10.78, 3.76),
            Offset(9.52, 3.76),
            Offset(9.352, 2.2),
            Offset(10.78, 2.2),
          ]);
          block(const [
            Offset(5.152, 5.68),
            Offset(6.496, 4.6),
            Offset(6.496, 3.76),
            Offset(5.152, 4.84),
          ]);
          block(const [
            Offset(5.152, 3.64),
            Offset(6.496, 2.56),
            Offset(6.496, 1.72),
            Offset(5.152, 2.8),
          ]);
          block(const [
            Offset(8.848, 5.68),
            Offset(7.504, 4.6),
            Offset(7.504, 3.76),
            Offset(8.848, 4.84),
          ]);
          block(const [
            Offset(8.848, 3.64),
            Offset(7.504, 2.56),
            Offset(7.504, 1.72),
            Offset(8.848, 2.8),
          ]);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(6.79, 4.36, 7.21, 6.16),
              const Radius.circular(0.084),
            ),
            fillPaint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(6.79, 1.96, 7.21, 3.76),
              const Radius.circular(0.084),
            ),
            fillPaint,
          );
        },
        width: 14,
        height: 8,
      );

    case RouteTexture.trainTrack:
      return _render(
        (canvas) {
          canvas.drawLine(
            Offset(size * 0.15, size / 2),
            Offset(size * 0.85, size / 2),
            paint,
          );
        },
        width: size,
        height: size,
      );
  }
}
