import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/core/routing/routing_service.dart';
import 'package:kumo_claude/core/routing/routing_service_provider.dart';
import 'package:kumo_claude/features/itinerary/data/repositories/trip_segment_repository_impl.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/trip_segment_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockRoutingService extends Mock implements RoutingService {}

class MockTripSegmentRepositoryImpl extends Mock
    implements TripSegmentRepositoryImpl {}

void main() {
  late MockRoutingService routingService;
  late MockTripSegmentRepositoryImpl repository;
  late ProviderContainer container;

  const segment = TripSegment(
    id: 'seg-1',
    itineraryId: 'it-1',
    orderIndex: 0,
    mode: TransportMode.car,
    origin: Waypoint(name: 'Chiang Mai', latitude: 18.7883, longitude: 98.9853),
    destination: Waypoint(name: 'Pai', latitude: 19.3583, longitude: 98.4400),
  );

  setUpAll(() {
    registerFallbackValue(
      const Waypoint(name: 'fallback', latitude: 0, longitude: 0),
    );
    registerFallbackValue(TransportMode.other);
  });

  setUp(() {
    routingService = MockRoutingService();
    repository = MockTripSegmentRepositoryImpl();

    container = ProviderContainer(
      overrides: [
        routingServiceProvider.overrideWithValue(routingService),
        tripSegmentRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('FetchTripSegmentRouteGeometry', () {
    test('does nothing for a non-routable mode (e.g. flight) — no network '
        'call, no cache write', () async {
      final fetch = container.read(fetchTripSegmentRouteGeometryProvider);
      await fetch(segment.copyWith(mode: TransportMode.flight));

      verifyNever(
        () => routingService.route(
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          mode: any(named: 'mode'),
        ),
      );
      verifyNever(() => repository.updateRouteGeometry(any(), any()));
    });

    test('clears a stale cached geometry before refetching, so an edit that '
        'changes origin/destination/mode never leaves the previous route '
        'looking valid for the new one', () async {
      when(
        () => repository.clearRouteGeometry(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => routingService.route(
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          mode: any(named: 'mode'),
        ),
      ).thenAnswer((_) async => null);

      final withStaleGeometry = segment.copyWith(
        routeGeometry: const [(18.7883, 98.9853), (19.3583, 98.4400)],
      );
      final fetch = container.read(fetchTripSegmentRouteGeometryProvider);
      await fetch(withStaleGeometry);

      verify(() => repository.clearRouteGeometry('seg-1')).called(1);
    });

    test('clears a stale cached geometry even when the new mode is not '
        'routable, instead of leaving the old road path behind', () async {
      when(
        () => repository.clearRouteGeometry(any()),
      ).thenAnswer((_) async => const Right(null));

      final staleThenFlight = segment.copyWith(
        mode: TransportMode.flight,
        routeGeometry: const [(18.7883, 98.9853), (19.3583, 98.4400)],
      );
      final fetch = container.read(fetchTripSegmentRouteGeometryProvider);
      await fetch(staleThenFlight);

      verify(() => repository.clearRouteGeometry('seg-1')).called(1);
      verifyNever(
        () => routingService.route(
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          mode: any(named: 'mode'),
        ),
      );
    });

    test('does not call clearRouteGeometry when there is nothing cached '
        'yet (fresh add / first-time backfill)', () async {
      when(
        () => routingService.route(
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          mode: any(named: 'mode'),
        ),
      ).thenAnswer((_) async => null);

      final fetch = container.read(fetchTripSegmentRouteGeometryProvider);
      await fetch(segment);

      verifyNever(() => repository.clearRouteGeometry(any()));
    });

    test('does not write to the repository when the routing service finds '
        'no route', () async {
      when(
        () => routingService.route(
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          mode: any(named: 'mode'),
        ),
      ).thenAnswer((_) async => null);

      final fetch = container.read(fetchTripSegmentRouteGeometryProvider);
      await fetch(segment);

      verifyNever(() => repository.updateRouteGeometry(any(), any()));
    });

    test(
      'caches the routed geometry on the segment when a route is found',
      () async {
        const geometry = [(18.7883, 98.9853), (19.0, 98.7), (19.3583, 98.4400)];
        when(
          () => routingService.route(
            origin: segment.origin,
            destination: segment.destination,
            mode: TransportMode.car,
          ),
        ).thenAnswer((_) async => geometry);
        when(
          () => repository.updateRouteGeometry(any(), any()),
        ).thenAnswer((_) async => const Right(null));

        final fetch = container.read(fetchTripSegmentRouteGeometryProvider);
        await fetch(segment);

        verify(
          () => repository.updateRouteGeometry('seg-1', geometry),
        ).called(1);
      },
    );

    test(
      'completes without throwing when caching the geometry fails '
      '(e.g. a schema mismatch like the missing route_geometry column)',
      () async {
        when(
          () => routingService.route(
            origin: any(named: 'origin'),
            destination: any(named: 'destination'),
            mode: any(named: 'mode'),
          ),
        ).thenAnswer(
          (_) async => const [(18.7883, 98.9853), (19.3583, 98.4400)],
        );
        when(() => repository.updateRouteGeometry(any(), any())).thenAnswer(
          (_) async => const Left(ServerFailure('column does not exist')),
        );

        final fetch = container.read(fetchTripSegmentRouteGeometryProvider);

        await expectLater(fetch(segment), completes);
      },
    );

    test(
      'passes the segment\'s own mode through to the routing service',
      () async {
        when(
          () => routingService.route(
            origin: any(named: 'origin'),
            destination: any(named: 'destination'),
            mode: any(named: 'mode'),
          ),
        ).thenAnswer((_) async => null);

        final fetch = container.read(fetchTripSegmentRouteGeometryProvider);
        await fetch(segment.copyWith(mode: TransportMode.walk));

        verify(
          () => routingService.route(
            origin: segment.origin,
            destination: segment.destination,
            mode: TransportMode.walk,
          ),
        ).called(1);
      },
    );
  });
}
