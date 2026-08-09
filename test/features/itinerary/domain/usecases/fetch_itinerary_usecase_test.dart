import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/itinerary_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/fetch_itinerary_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockItineraryRepository extends Mock implements ItineraryRepository {}

void main() {
  late MockItineraryRepository mockRepo;
  late FetchItineraryUseCase useCase;

  final tStart = DateTime(2026, 9);
  final tEnd = DateTime(2026, 9, 7);

  final tItinerary = TravelItinerary(
    id: 'it-1',
    title: 'Chiang Mai Trip',
    ownerId: 'user-1',
    startDate: tStart,
    endDate: tEnd,
    totalBudget: 0,
    currencyCode: 'USD',
    members: const [],
    items: const [],
    expenseSummary: const ExpenseSummary(
      totalSpent: 0,
      spentByCategory: {},
      memberBalances: {},
    ),
    createdAt: tStart,
    updatedAt: tStart,
  );

  setUp(() {
    mockRepo = MockItineraryRepository();
    useCase = FetchItineraryUseCase(mockRepo);
  });

  test('delegates to repository with the given id', () async {
    when(
      () => mockRepo.fetchItinerary('it-1'),
    ).thenAnswer((_) async => Right(tItinerary));

    final result = await useCase('it-1');

    verify(() => mockRepo.fetchItinerary('it-1')).called(1);
    result.fold(
      (_) => fail('expected Right'),
      (itinerary) => expect(itinerary, tItinerary),
    );
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.fetchItinerary(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('it-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
