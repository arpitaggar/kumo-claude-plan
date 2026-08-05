import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/maps/route_texture.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';

void main() {
  group('textureForMode', () {
    test('walk maps to footsteps', () {
      expect(textureForMode(TransportMode.walk), RouteTexture.footsteps);
    });

    test('motorcycle maps to singleTread', () {
      expect(
        textureForMode(TransportMode.motorcycle),
        RouteTexture.singleTread,
      );
    });

    test('car and bus both map to doubleTread', () {
      expect(textureForMode(TransportMode.car), RouteTexture.doubleTread);
      expect(textureForMode(TransportMode.bus), RouteTexture.doubleTread);
    });

    test('train maps to trainTrack', () {
      expect(textureForMode(TransportMode.train), RouteTexture.trainTrack);
    });

    test('flight, ferry, and other all map to dashedLine', () {
      expect(textureForMode(TransportMode.flight), RouteTexture.dashedLine);
      expect(textureForMode(TransportMode.ferry), RouteTexture.dashedLine);
      expect(textureForMode(TransportMode.other), RouteTexture.dashedLine);
    });
  });

  group('tickCountForTexture', () {
    test('dashedLine has no ticks', () {
      expect(tickCountForTexture(RouteTexture.dashedLine), 0);
    });

    test('every ticked texture has a positive count', () {
      for (final texture in RouteTexture.values) {
        if (texture == RouteTexture.dashedLine) {
          continue;
        }
        expect(
          tickCountForTexture(texture),
          greaterThan(0),
          reason: '$texture should have a positive tick count',
        );
      }
    });

    test('doubleTread is denser than singleTread, which is denser than '
        'footsteps and trainTrack', () {
      final doubleTread = tickCountForTexture(RouteTexture.doubleTread);
      final singleTread = tickCountForTexture(RouteTexture.singleTread);
      final footsteps = tickCountForTexture(RouteTexture.footsteps);
      final trainTrack = tickCountForTexture(RouteTexture.trainTrack);

      expect(doubleTread, greaterThan(singleTread));
      expect(singleTread, greaterThan(footsteps));
      expect(singleTread, greaterThan(trainTrack));
    });
  });
}
