import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/trip_cost_field_value_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/set_trip_cost_field_values_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockTripCostFieldValueRepository extends Mock
    implements TripCostFieldValueRepository {}

void main() {
  late MockTripCostFieldValueRepository mockRepo;
  late SetTripCostFieldValuesUseCase useCase;

  setUp(() {
    mockRepo = MockTripCostFieldValueRepository();
    useCase = SetTripCostFieldValuesUseCase(mockRepo);
  });

  test('delegates to repository with itineraryId and the field map', () async {
    when(
      () => mockRepo.setValues('it-1', {'field-1': 'option-1'}),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase('it-1', {'field-1': 'option-1'});

    verify(() => mockRepo.setValues('it-1', {'field-1': 'option-1'})).called(1);
    expect(result, const Right<Failure, void>(null));
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.setValues(any(), any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('it-1', {'field-1': 'option-1'});

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
