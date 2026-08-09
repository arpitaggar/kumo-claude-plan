import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/data/datasources/trip_cost_field_value_remote_datasource.dart';
import 'package:kumo_claude/features/itinerary/data/models/trip_cost_field_value_model.dart';
import 'package:kumo_claude/features/itinerary/data/repositories/trip_cost_field_value_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockTripCostFieldValueRemoteDataSource extends Mock
    implements TripCostFieldValueRemoteDataSource {}

void main() {
  late MockTripCostFieldValueRemoteDataSource dataSource;
  late TripCostFieldValueRepositoryImpl repository;

  const tValue = TripCostFieldValueModel(
    itineraryId: 'it-1',
    fieldId: 'field-1',
    optionId: 'option-1',
  );

  setUp(() {
    dataSource = MockTripCostFieldValueRemoteDataSource();
    repository = TripCostFieldValueRepositoryImpl(dataSource: dataSource);
  });

  group('fetchValues', () {
    test('returns Right(values) on success', () async {
      when(
        () => dataSource.fetchValues(any()),
      ).thenAnswer((_) async => [tValue]);

      final result = await repository.fetchValues('it-1');

      result.fold(
        (_) => fail('expected Right'),
        (values) => expect(values, [tValue]),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.fetchValues(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.fetchValues('it-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps an unexpected exception to UnexpectedFailure', () async {
      when(() => dataSource.fetchValues(any())).thenThrow(Exception('boom'));

      final result = await repository.fetchValues('it-1');

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('setValues', () {
    test('returns Right(null) on success', () async {
      when(() => dataSource.setValues(any(), any())).thenAnswer((_) async {});

      final result = await repository.setValues('it-1', {
        'field-1': 'option-1',
      });

      expect(result, const Right<Failure, void>(null));
      verify(
        () => dataSource.setValues('it-1', {'field-1': 'option-1'}),
      ).called(1);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.setValues(any(), any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.setValues('it-1', {
        'field-1': 'option-1',
      });

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
