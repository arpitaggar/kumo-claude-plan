import 'package:xml/xml.dart';

import 'geocoding_service.dart';

/// Thrown by [parseGpxWaypoints] when the file isn't recognizable GPX, or
/// contains no point data this app knows how to offer as a location.
class GpxParseException implements Exception {
  const GpxParseException(this.message);
  final String message;
}

/// Extracts named points from a `.gpx` file (the standard GPS Exchange
/// Format most GPS devices/apps export) that a user can pick from when
/// setting a trip segment's origin/destination.
///
/// Prefers `<wpt>` waypoints (what most apps export for points of
/// interest); if a file has none, falls back to `<rte>` route points, then
/// to just the first/last point of each `<trk>` track segment — enough to
/// pick a *single* location, which is all a segment endpoint needs.
List<GeocodingResult> parseGpxWaypoints(String xmlString) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(xmlString);
  } on XmlException {
    throw const GpxParseException("This doesn't look like a GPX file.");
  }

  final root = doc.rootElement;
  if (root.name.local != 'gpx') {
    throw const GpxParseException("This doesn't look like a GPX file.");
  }

  final results = <GeocodingResult>[];

  for (final wpt in root.findElements('wpt')) {
    final point = _pointFromElement(
      wpt,
      fallbackName: 'Waypoint ${results.length + 1}',
    );
    if (point != null) {
      results.add(point);
    }
  }

  if (results.isEmpty) {
    for (final rte in root.findElements('rte')) {
      for (final pt in rte.findElements('rtept')) {
        final point = _pointFromElement(
          pt,
          fallbackName: 'Route point ${results.length + 1}',
        );
        if (point != null) {
          results.add(point);
        }
      }
    }
  }

  if (results.isEmpty) {
    for (final trk in root.findElements('trk')) {
      for (final seg in trk.findElements('trkseg')) {
        final points = seg.findElements('trkpt').toList();
        if (points.isEmpty) {
          continue;
        }
        final start = _pointFromElement(
          points.first,
          fallbackName: 'Track start',
        );
        if (start != null) {
          results.add(start);
        }
        if (points.length > 1) {
          final end = _pointFromElement(points.last, fallbackName: 'Track end');
          if (end != null) {
            results.add(end);
          }
        }
      }
    }
  }

  if (results.isEmpty) {
    throw const GpxParseException('No usable points found in this GPX file.');
  }
  return results;
}

GeocodingResult? _pointFromElement(
  XmlElement element, {
  required String fallbackName,
}) {
  final latStr = element.getAttribute('lat');
  final lonStr = element.getAttribute('lon');
  if (latStr == null || lonStr == null) {
    return null;
  }
  final lat = double.tryParse(latStr);
  final lon = double.tryParse(lonStr);
  if (lat == null ||
      lon == null ||
      lat < -90 ||
      lat > 90 ||
      lon < -180 ||
      lon > 180) {
    return null;
  }
  final name = element.findElements('name').firstOrNull?.innerText.trim();
  return GeocodingResult(
    name: (name != null && name.isNotEmpty) ? name : fallbackName,
    latitude: lat,
    longitude: lon,
  );
}
