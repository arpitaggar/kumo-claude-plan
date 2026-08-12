import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/hitchhiker/domain/entities/hitchhiker.dart';
import 'package:kumo_claude/features/hitchhiker/domain/repositories/hitchhiker_repository.dart';
import 'package:kumo_claude/features/hitchhiker/domain/usecases/create_hitchhiker_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockHitchhikerRepository extends Mock implements HitchhikerRepository {}

void main() {
  late MockHitchhikerRepository mockRepo;
  late CreateHitchhikerUseCase useCase;

  final tHitchhiker = Hitchhiker(
    id: 'hh-1',
    itineraryId: 'trip-1',
    displayName: 'Priya',
    accessToken: 'token-abc',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    mockRepo = MockHitchhikerRepository();
    useCase = CreateHitchhikerUseCase(mockRepo);
  });

  group('CreateHitchhikerUseCase — validation', () {
    test('rejects an empty name without calling the repository', () async {
      final result = await useCase(itineraryId: 'trip-1', displayName: '');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
      verifyNever(
        () => mockRepo.createHitchhiker(
          itineraryId: any(named: 'itineraryId'),
          displayName: any(named: 'displayName'),
        ),
      );
    });

    test('rejects a whitespace-only name', () async {
      final result = await useCase(itineraryId: 'trip-1', displayName: '   ');

      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('rejects a name over 60 characters', () async {
      final result = await useCase(
        itineraryId: 'trip-1',
        displayName: 'a' * 61,
      );

      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('accepts a 60-character name', () async {
      when(
        () => mockRepo.createHitchhiker(
          itineraryId: any(named: 'itineraryId'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async => Right(tHitchhiker));

      final result = await useCase(
        itineraryId: 'trip-1',
        displayName: 'a' * 60,
      );

      expect(result.isRight(), isTrue);
    });
  });

  group('CreateHitchhikerUseCase — repository delegation', () {
    test('trims the name before delegating', () async {
      when(
        () => mockRepo.createHitchhiker(
          itineraryId: 'trip-1',
          displayName: 'Priya',
        ),
      ).thenAnswer((_) async => Right(tHitchhiker));

      await useCase(itineraryId: 'trip-1', displayName: '  Priya  ');

      verify(
        () => mockRepo.createHitchhiker(
          itineraryId: 'trip-1',
          displayName: 'Priya',
        ),
      ).called(1);
    });

    test('returns Right(hitchhiker) on success', () async {
      when(
        () => mockRepo.createHitchhiker(
          itineraryId: any(named: 'itineraryId'),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async => Right(tHitchhiker));

      final result = await useCase(itineraryId: 'trip-1', displayName: 'Priya');

      expect(result, Right<Failure, Hitchhiker>(tHitchhiker));
    });

    test(
      'propagates AuthFailure from repository (e.g. not the trip owner)',
      () async {
        when(
          () => mockRepo.createHitchhiker(
            itineraryId: any(named: 'itineraryId'),
            displayName: any(named: 'displayName'),
          ),
        ).thenAnswer(
          (_) async => const Left(
            AuthFailure('Only the trip owner can add a Hitchhiker'),
          ),
        );

        final result = await useCase(
          itineraryId: 'trip-1',
          displayName: 'Priya',
        );

        result.fold(
          (f) => expect(f, isA<AuthFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });
}
