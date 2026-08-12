import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/data/datasources/trip_segment_remote_datasource.dart';
import 'package:kumo_claude/features/itinerary/data/models/trip_segment_model.dart';
import 'package:kumo_claude/features/itinerary/data/repositories/trip_segment_repository_impl.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/transport_mode.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_segment.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/waypoint.dart';
import 'package:mocktail/mocktail.dart';

class MockTripSegmentRemoteDataSource extends Mock
    implements TripSegmentRemoteDataSource {}

void main() {
  late MockTripSegmentRemoteDataSource dataSource;
  late TripSegmentRepositoryImpl repository;

  const origin = Waypoint(
    name: 'Chiang Mai',
    latitude: 18.7883,
    longitude: 98.9853,
  );
  const destination = Waypoint(
    name: 'Pai',
    latitude: 19.3583,
    longitude: 98.44,
  );

  const tSegment = TripSegment(
    id: 'seg-1',
    itineraryId: 'it-1',
    orderIndex: 0,
    mode: TransportMode.car,
    origin: origin,
    destination: destination,
  );

  const tModel = TripSegmentModel(
    id: 'seg-1',
    itineraryId: 'it-1',
    orderIndex: 0,
    mode: TransportMode.car,
    origin: origin,
    destination: destination,
  );

  setUpAll(() {
    registerFallbackValue(tModel);
  });

  setUp(() {
    dataSource = MockTripSegmentRemoteDataSource();
    repository = TripSegmentRepositoryImpl(dataSource: dataSource);
  });

  group('watchSegments', () {
    test('maps a data-source stream to Right', () async {
      when(
        () => dataSource.watchSegments('it-1'),
      ).thenAnswer((_) => Stream.value([tModel]));

      final result = await repository.watchSegments('it-1').first;

      result.fold(
        (_) => fail('expected Right'),
        (segments) => expect(segments, [tModel]),
      );
    });

    test(
      'maps a ServerException on the stream to Left(ServerFailure)',
      () async {
        when(() => dataSource.watchSegments('it-1')).thenAnswer(
          (_) => Stream<List<TripSegmentModel>>.error(
            ServerException(message: 'boom'),
          ),
        );

        final result = await repository.watchSegments('it-1').first;

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });

  group('addSegment', () {
    test('returns Right(segment) on success', () async {
      when(() => dataSource.addSegment(any())).thenAnswer((_) async => tModel);

      final result = await repository.addSegment(tSegment);

      result.fold(
        (_) => fail('expected Right'),
        (segment) => expect(segment, tModel),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.addSegment(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.addSegment(tSegment);

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('updateSegment', () {
    test('returns Right(segment) on success', () async {
      when(
        () => dataSource.updateSegment(any()),
      ).thenAnswer((_) async => tModel);

      final result = await repository.updateSegment(tSegment);

      result.fold(
        (_) => fail('expected Right'),
        (segment) => expect(segment, tModel),
      );
    });

    test('maps an unexpected exception to UnexpectedFailure', () async {
      when(() => dataSource.updateSegment(any())).thenThrow(Exception('boom'));

      final result = await repository.updateSegment(tSegment);

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('deleteSegment', () {
    test('returns Right(null) on success', () async {
      when(() => dataSource.deleteSegment(any())).thenAnswer((_) async {});

      final result = await repository.deleteSegment('seg-1');

      expect(result, const Right<Failure, void>(null));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.deleteSegment(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.deleteSegment('seg-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('reorderSegments', () {
    test('returns Right(null) on success', () async {
      when(() => dataSource.reorderSegments(any())).thenAnswer((_) async {});

      final result = await repository.reorderSegments('it-1', [tSegment]);

      expect(result, const Right<Failure, void>(null));
      verify(() => dataSource.reorderSegments(any())).called(1);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.reorderSegments(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.reorderSegments('it-1', [tSegment]);

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('updateRouteGeometry', () {
    const geometry = [(18.7883, 98.9853), (19.3583, 98.44)];

    test('returns Right(null) on success', () async {
      when(
        () => dataSource.updateRouteGeometry(any(), any()),
      ).thenAnswer((_) async {});

      final result = await repository.updateRouteGeometry('seg-1', geometry);

      expect(result, const Right<Failure, void>(null));
      verify(() => dataSource.updateRouteGeometry('seg-1', geometry)).called(1);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.updateRouteGeometry(any(), any()),
      ).thenThrow(ServerException(message: 'column does not exist'));

      final result = await repository.updateRouteGeometry('seg-1', geometry);

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('clearRouteGeometry', () {
    test('returns Right(null) on success', () async {
      when(() => dataSource.clearRouteGeometry(any())).thenAnswer((_) async {});

      final result = await repository.clearRouteGeometry('seg-1');

      expect(result, const Right<Failure, void>(null));
      verify(() => dataSource.clearRouteGeometry('seg-1')).called(1);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.clearRouteGeometry(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.clearRouteGeometry('seg-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps an unexpected exception to UnexpectedFailure', () async {
      when(
        () => dataSource.clearRouteGeometry(any()),
      ).thenThrow(Exception('boom'));

      final result = await repository.clearRouteGeometry('seg-1');

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('setSegmentVisibility', () {
    test('returns Right(null) on success', () async {
      when(
        () =>
            dataSource.setVisibility(any(), isVisible: any(named: 'isVisible')),
      ).thenAnswer((_) async {});

      final result = await repository.setSegmentVisibility(
        'seg-1',
        isVisible: false,
      );

      expect(result, const Right<Failure, void>(null));
      verify(
        () => dataSource.setVisibility('seg-1', isVisible: false),
      ).called(1);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () =>
            dataSource.setVisibility(any(), isVisible: any(named: 'isVisible')),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.setSegmentVisibility(
        'seg-1',
        isVisible: true,
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
