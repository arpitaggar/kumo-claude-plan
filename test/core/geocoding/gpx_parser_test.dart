import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/geocoding/gpx_parser.dart';

const _waypointsGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
  <wpt lat="35.6762" lon="139.6503">
    <name>Tokyo</name>
  </wpt>
  <wpt lat="34.6937" lon="135.5023">
    <name>Osaka</name>
  </wpt>
</gpx>
''';

const _unnamedWaypointGpx = '''
<gpx xmlns="http://www.topografix.com/GPX/1/1">
  <wpt lat="48.1351" lon="11.5820"></wpt>
</gpx>
''';

const _trackOnlyGpx = '''
<gpx xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <trkseg>
      <trkpt lat="1.0" lon="2.0"></trkpt>
      <trkpt lat="3.0" lon="4.0"></trkpt>
      <trkpt lat="5.0" lon="6.0"></trkpt>
    </trkseg>
  </trk>
</gpx>
''';

const _emptyGpx = '''
<gpx xmlns="http://www.topografix.com/GPX/1/1"></gpx>
''';

void main() {
  group('parseGpxWaypoints', () {
    test('extracts named waypoints', () {
      final points = parseGpxWaypoints(_waypointsGpx);

      expect(points, hasLength(2));
      expect(points[0].name, 'Tokyo');
      expect(points[0].latitude, 35.6762);
      expect(points[0].longitude, 139.6503);
      expect(points[1].name, 'Osaka');
    });

    test('falls back to a numbered name when <name> is missing', () {
      final points = parseGpxWaypoints(_unnamedWaypointGpx);

      expect(points, hasLength(1));
      expect(points.single.name, 'Waypoint 1');
    });

    test(
      'falls back to track start/end when there are no waypoints or routes',
      () {
        final points = parseGpxWaypoints(_trackOnlyGpx);

        expect(points, hasLength(2));
        expect(points[0].name, 'Track start');
        expect(points[0].latitude, 1.0);
        expect(points[1].name, 'Track end');
        expect(points[1].latitude, 5.0);
      },
    );

    test('throws GpxParseException for a file with no usable points', () {
      expect(
        () => parseGpxWaypoints(_emptyGpx),
        throwsA(isA<GpxParseException>()),
      );
    });

    test('throws GpxParseException for invalid XML', () {
      expect(
        () => parseGpxWaypoints('not xml at all'),
        throwsA(isA<GpxParseException>()),
      );
    });

    test('throws GpxParseException for XML that is not GPX', () {
      expect(
        () => parseGpxWaypoints('<not-gpx></not-gpx>'),
        throwsA(isA<GpxParseException>()),
      );
    });
  });
}
