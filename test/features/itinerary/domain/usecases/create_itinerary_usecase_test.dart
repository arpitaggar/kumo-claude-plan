import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/itinerary_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/create_itinerary_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockItineraryRepository extends Mock implements ItineraryRepository {}

void main() {
  late MockItineraryRepository mockRepo;
  late CreateItineraryUseCase useCase;

  final tStart = DateTime(2026, 9);
  final tEnd = DateTime(2026, 9, 7);

  setUpAll(() {
    registerFallbackValue(
      TravelItinerary(
        id: '',
        title: '',
        ownerId: '',
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
      ),
    );
  });

  setUp(() {
    mockRepo = MockItineraryRepository();
    useCase = CreateItineraryUseCase(mockRepo);

    // Default: repository succeeds — return value validated separately
    when(() => mockRepo.createItinerary(any())).thenAnswer(
      (inv) async => Right(inv.positionalArguments[0] as TravelItinerary),
    );
  });

  group('CreateItineraryUseCase — validation', () {
    test('returns ValidationFailure for empty title', () async {
      final result = await useCase(
        title: '',
        ownerId: 'user-1',
        ownerName: 'Alice',
        startDate: tStart,
        endDate: tEnd,
        totalBudget: 1000,
        currencyCode: 'USD',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
      verifyNever(() => mockRepo.createItinerary(any()));
    });

    test('returns ValidationFailure for whitespace-only title', () async {
      final result = await useCase(
        title: '   ',
        ownerId: 'user-1',
        ownerName: 'Alice',
        startDate: tStart,
        endDate: tEnd,
        totalBudget: 1000,
        currencyCode: 'USD',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'returns ValidationFailure when end date is before start date',
      () async {
        final result = await useCase(
          title: 'Tokyo Trip',
          ownerId: 'user-1',
          ownerName: 'Alice',
          startDate: tEnd,
          endDate: tStart,
          totalBudget: 1000,
          currencyCode: 'USD',
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (f) => expect(f, isA<ValidationFailure>()),
          (_) => fail('expected Left'),
        );
        verifyNever(() => mockRepo.createItinerary(any()));
      },
    );

    test('returns ValidationFailure for negative budget', () async {
      final result = await useCase(
        title: 'Tokyo Trip',
        ownerId: 'user-1',
        ownerName: 'Alice',
        startDate: tStart,
        endDate: tEnd,
        totalBudget: -1,
        currencyCode: 'USD',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('CreateItineraryUseCase — entity construction', () {
    test('adds owner as a GroupMember with owner role', () async {
      TravelItinerary? captured;
      when(() => mockRepo.createItinerary(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as TravelItinerary;
        return Right(captured!);
      });

      await useCase(
        title: 'Tokyo Trip',
        ownerId: 'user-1',
        ownerName: 'Alice',
        startDate: tStart,
        endDate: tEnd,
        totalBudget: 1500,
        currencyCode: 'USD',
      );

      expect(captured, isNotNull);
      expect(captured!.members, hasLength(1));
      expect(captured!.members.first.userId, 'user-1');
      expect(captured!.members.first.role, GroupMemberRole.owner);
    });

    test('trims title before persisting', () async {
      TravelItinerary? captured;
      when(() => mockRepo.createItinerary(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as TravelItinerary;
        return Right(captured!);
      });

      await useCase(
        title: '  Tokyo Trip  ',
        ownerId: 'user-1',
        ownerName: 'Alice',
        startDate: tStart,
        endDate: tEnd,
        totalBudget: 1500,
        currencyCode: 'USD',
      );

      expect(captured!.title, 'Tokyo Trip');
    });

    test('seeds items list when provided', () async {
      final item = ItineraryItem(
        id: 'item-1',
        itemType: 'activity',
        title: 'Visit Senso-ji',
        startTime: tStart,
      );

      TravelItinerary? captured;
      when(() => mockRepo.createItinerary(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as TravelItinerary;
        return Right(captured!);
      });

      await useCase(
        title: 'Tokyo Trip',
        ownerId: 'user-1',
        ownerName: 'Alice',
        startDate: tStart,
        endDate: tEnd,
        totalBudget: 1500,
        currencyCode: 'USD',
        items: [item],
      );

      expect(captured!.items, hasLength(1));
      expect(captured!.items.first.title, 'Visit Senso-ji');
    });

    test('initialises expense summary to zero', () async {
      TravelItinerary? captured;
      when(() => mockRepo.createItinerary(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as TravelItinerary;
        return Right(captured!);
      });

      await useCase(
        title: 'Tokyo Trip',
        ownerId: 'user-1',
        ownerName: 'Alice',
        startDate: tStart,
        endDate: tEnd,
        totalBudget: 1500,
        currencyCode: 'USD',
      );

      expect(captured!.expenseSummary.totalSpent, 0.0);
      expect(captured!.expenseSummary.spentByCategory, isEmpty);
    });
  });

  group('CreateItineraryUseCase — repository delegation', () {
    test('returns Right(itinerary) on repository success', () async {
      final result = await useCase(
        title: 'Tokyo Trip',
        ownerId: 'user-1',
        ownerName: 'Alice',
        startDate: tStart,
        endDate: tEnd,
        totalBudget: 1500,
        currencyCode: 'USD',
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (it) => expect(it.title, 'Tokyo Trip'),
      );
    });

    test('propagates ServerFailure from repository', () async {
      when(
        () => mockRepo.createItinerary(any()),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await useCase(
        title: 'Tokyo Trip',
        ownerId: 'user-1',
        ownerName: 'Alice',
        startDate: tStart,
        endDate: tEnd,
        totalBudget: 1500,
        currencyCode: 'USD',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
