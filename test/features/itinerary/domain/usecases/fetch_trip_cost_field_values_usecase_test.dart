import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_cost_field_value.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/trip_cost_field_value_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/fetch_trip_cost_field_values_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockTripCostFieldValueRepository extends Mock
    implements TripCostFieldValueRepository {}

void main() {
  late MockTripCostFieldValueRepository mockRepo;
  late FetchTripCostFieldValuesUseCase useCase;

  const tValue = TripCostFieldValue(
    itineraryId: 'it-1',
    fieldId: 'field-1',
    optionId: 'option-1',
  );

  setUp(() {
    mockRepo = MockTripCostFieldValueRepository();
    useCase = FetchTripCostFieldValuesUseCase(mockRepo);
  });

  test('delegates to repository with the given itineraryId', () async {
    when(
      () => mockRepo.fetchValues('it-1'),
    ).thenAnswer((_) async => const Right([tValue]));

    final result = await useCase('it-1');

    verify(() => mockRepo.fetchValues('it-1')).called(1);
    result.fold(
      (_) => fail('expected Right'),
      (values) => expect(values, const [tValue]),
    );
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.fetchValues(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('it-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
