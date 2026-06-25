import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/itinerary_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/update_itinerary_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockItineraryRepository extends Mock implements ItineraryRepository {}

void main() {
  late MockItineraryRepository mockRepo;
  late UpdateItineraryUseCase useCase;

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
    useCase = UpdateItineraryUseCase(mockRepo);

    registerFallbackValue(tItinerary);
    when(() => mockRepo.updateItinerary(any()))
        .thenAnswer((_) async => Right(tItinerary));
  });

  group('UpdateItineraryUseCase — validation', () {
    test('returns ValidationFailure for empty title', () async {
      final result = await useCase(tItinerary.copyWith(title: ''));

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
      verifyNever(() => mockRepo.updateItinerary(any()));
    });

    test('returns ValidationFailure when end date is before start date',
        () async {
      final bad = tItinerary.copyWith(
        startDate: DateTime(2026, 10, 7),
        endDate: DateTime(2026, 10),
      );

      final result = await useCase(bad);

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('returns ValidationFailure for negative budget', () async {
      final result = await useCase(tItinerary.copyWith(totalBudget: -100));

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('UpdateItineraryUseCase — repository delegation', () {
    test('calls repository with updatedAt set to now (UTC)', () async {
      final before = DateTime.now().toUtc();

      TravelItinerary? captured;
      when(() => mockRepo.updateItinerary(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as TravelItinerary;
        return Right(captured!);
      });

      await useCase(tItinerary);

      expect(captured, isNotNull);
      expect(captured!.updatedAt.isAfter(before), isTrue);
      expect(captured!.updatedAt.isUtc, isTrue);
    });

    test('returns Right(itinerary) on success', () async {
      final result = await useCase(tItinerary);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (it) => expect(it.title, 'Paris Trip'),
      );
    });

    test('propagates ServerFailure from repository', () async {
      when(() => mockRepo.updateItinerary(any()))
          .thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await useCase(tItinerary);

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
