import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/data/datasources/trip_email_alias_remote_datasource.dart';
import 'package:kumo_claude/features/itinerary/data/models/trip_email_alias_model.dart';
import 'package:kumo_claude/features/itinerary/data/repositories/trip_email_alias_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockTripEmailAliasRemoteDataSource extends Mock
    implements TripEmailAliasRemoteDataSource {}

void main() {
  late MockTripEmailAliasRemoteDataSource dataSource;
  late TripEmailAliasRepositoryImpl repository;

  const tAlias = TripEmailAliasModel(
    itineraryId: 'it-1',
    localPart: 'trip-x7k2m9qz',
    domain: 'trips.kumo.app',
  );

  setUp(() {
    dataSource = MockTripEmailAliasRemoteDataSource();
    repository = TripEmailAliasRepositoryImpl(dataSource: dataSource);
  });

  group('getAlias', () {
    test('returns Right(alias) on success', () async {
      when(() => dataSource.fetchAlias(any())).thenAnswer((_) async => tAlias);

      final result = await repository.getAlias('it-1');

      result.fold(
        (_) => fail('expected Right'),
        (alias) => expect(alias, tAlias),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.fetchAlias(any()),
      ).thenThrow(ServerException(message: 'not found'));

      final result = await repository.getAlias('it-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps an unexpected exception to UnexpectedFailure', () async {
      when(() => dataSource.fetchAlias(any())).thenThrow(Exception('boom'));

      final result = await repository.getAlias('it-1');

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
