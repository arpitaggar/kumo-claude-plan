import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/data/datasources/itinerary_local_datasource.dart';
import 'package:kumo_claude/features/itinerary/data/datasources/itinerary_remote_datasource.dart';
import 'package:kumo_claude/features/itinerary/data/models/itinerary_model.dart';
import 'package:kumo_claude/features/itinerary/data/repositories/itinerary_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockItineraryRemoteDataSource extends Mock
    implements ItineraryRemoteDataSource {}

class MockItineraryLocalDataSource extends Mock
    implements ItineraryLocalDataSource {}

void main() {
  late MockItineraryRemoteDataSource remote;
  late MockItineraryLocalDataSource local;
  late ItineraryRepositoryImpl repository;

  final tItinerary = ItineraryModel.fromJson({
    'id': 'it-1',
    'title': 'Chiang Mai Trip',
    'owner_id': 'user-1',
    'start_date': '2026-06-01T00:00:00.000Z',
    'end_date': '2026-06-07T00:00:00.000Z',
    'total_budget': 1000.0,
    'currency_code': 'USD',
    'members': <Map<String, dynamic>>[],
    'items': <Map<String, dynamic>>[],
    'expense_summary': <String, dynamic>{
      'total_spent': 0,
      'spent_by_category': <String, dynamic>{},
      'member_balances': <String, dynamic>{},
    },
    'created_at': '2026-05-01T00:00:00.000Z',
    'updated_at': '2026-05-01T00:00:00.000Z',
  });

  setUp(() {
    remote = MockItineraryRemoteDataSource();
    local = MockItineraryLocalDataSource();
    repository = ItineraryRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
    );
  });

  group('watchItinerary', () {
    // Regression coverage: this stream used to be built with
    // `.map(Right.new).handleError((e) => Left(...))` — Stream.handleError's
    // callback return value is silently discarded, so a data-source stream
    // error used to vanish instead of ever reaching subscribers as a
    // Left(Failure). See the matching fix's comment in
    // lib/features/itinerary/data/repositories/itinerary_repository_impl.dart.
    test('maps a data-source stream to Right', () async {
      when(
        () => remote.watchItinerary('it-1'),
      ).thenAnswer((_) => Stream.value(tItinerary));

      final result = await repository.watchItinerary('it-1').first;

      result.fold(
        (_) => fail('expected Right'),
        (itinerary) => expect(itinerary, tItinerary),
      );
    });

    test(
      'maps a stream error to Left(Failure) instead of dropping it',
      () async {
        when(() => remote.watchItinerary('it-1')).thenAnswer(
          (_) => Stream<ItineraryModel>.error(
            ServerException(message: 'connection lost'),
          ),
        );

        final result = await repository.watchItinerary('it-1').first;

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });
}
