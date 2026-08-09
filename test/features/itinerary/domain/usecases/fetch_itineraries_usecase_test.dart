import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/itinerary_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/fetch_itineraries_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockItineraryRepository extends Mock implements ItineraryRepository {}

void main() {
  late MockItineraryRepository mockRepo;
  late FetchItinerariesUseCase useCase;

  final tItinerary = TravelItinerary(
    id: 'it-1',
    title: 'Paris Trip',
    ownerId: 'user-1',
    startDate: DateTime(2026, 10),
    endDate: DateTime(2026, 10, 7),
    totalBudget: 2000,
    currencyCode: 'EUR',
    members: const [],
    items: const [],
    expenseSummary: const ExpenseSummary(
      totalSpent: 0,
      spentByCategory: {},
      memberBalances: {},
    ),
    createdAt: DateTime(2026, 6),
    updatedAt: DateTime(2026, 6),
  );

  setUp(() {
    mockRepo = MockItineraryRepository();
    useCase = FetchItinerariesUseCase(mockRepo);
  });

  test('delegates to repository with the provided userId', () async {
    when(
      () => mockRepo.fetchItineraries('user-1'),
    ).thenAnswer((_) async => Right([tItinerary]));

    await useCase('user-1');

    verify(() => mockRepo.fetchItineraries('user-1')).called(1);
  });

  test('returns Right(list) on success', () async {
    when(
      () => mockRepo.fetchItineraries('user-1'),
    ).thenAnswer((_) async => Right([tItinerary]));

    final result = await useCase('user-1');

    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected Right'), (list) {
      expect(list, hasLength(1));
      expect(list.first.title, 'Paris Trip');
    });
  });

  test('returns Right([]) when user has no itineraries', () async {
    when(
      () => mockRepo.fetchItineraries('user-2'),
    ).thenAnswer((_) async => const Right([]));

    final result = await useCase('user-2');

    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected Right'), (list) => expect(list, isEmpty));
  });

  test('propagates NetworkFailure from repository', () async {
    when(
      () => mockRepo.fetchItineraries(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure('No internet')));

    final result = await useCase('user-1');

    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<NetworkFailure>()),
      (_) => fail('expected Left'),
    );
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.fetchItineraries(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('user-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
