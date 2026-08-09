import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/routing/routing_service.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';

void main() {
  group('isRoutableMode', () {
    test('is true for car, motorcycle, bus, and walk', () {
      expect(isRoutableMode(TransportMode.car), isTrue);
      expect(isRoutableMode(TransportMode.motorcycle), isTrue);
      expect(isRoutableMode(TransportMode.bus), isTrue);
      expect(isRoutableMode(TransportMode.walk), isTrue);
    });

    test('is false for flight, train, ferry, and other', () {
      expect(isRoutableMode(TransportMode.flight), isFalse);
      expect(isRoutableMode(TransportMode.train), isFalse);
      expect(isRoutableMode(TransportMode.ferry), isFalse);
      expect(isRoutableMode(TransportMode.other), isFalse);
    });
  });
}
