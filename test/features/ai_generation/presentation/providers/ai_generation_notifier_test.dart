import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/ai_generation/domain/entities/ai_generation_request.dart';
import 'package:kumo_claude/features/ai_generation/domain/entities/ai_generation_result.dart';
import 'package:kumo_claude/features/ai_generation/domain/usecases/generate_itinerary_usecase.dart';
import 'package:kumo_claude/features/ai_generation/presentation/providers/ai_generation_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockGenerateItineraryUseCase extends Mock
    implements GenerateItineraryUseCase {}

void main() {
  late MockGenerateItineraryUseCase useCase;
  late AiGenerationNotifier notifier;

  final tRequest = AiGenerationRequest(
    destination: 'Tokyo',
    startDate: DateTime.utc(2026, 6),
    endDate: DateTime.utc(2026, 6, 7),
    travelStyle: TravelStyle.culture,
  );

  setUp(() {
    useCase = MockGenerateItineraryUseCase();
    notifier = AiGenerationNotifier(useCase);
  });

  test('starts in AiGenerationIdle', () {
    expect(notifier.state, isA<AiGenerationIdle>());
  });

  group('generate', () {
    test('transitions Loading -> Success on success', () async {
      const result = AiGenerationResult(items: []);
      when(
        () => useCase(tRequest),
      ).thenAnswer((_) async => const Right(result));

      final future = notifier.generate(tRequest);
      expect(notifier.state, isA<AiGenerationLoading>());
      await future;

      final state = notifier.state;
      expect(state, isA<AiGenerationSuccess>());
      expect((state as AiGenerationSuccess).result, result);
    });

    test('transitions Loading -> Error on failure', () async {
      when(
        () => useCase(tRequest),
      ).thenAnswer((_) async => const Left(ServerFailure('AI unavailable')));

      await notifier.generate(tRequest);

      final state = notifier.state;
      expect(state, isA<AiGenerationError>());
      expect((state as AiGenerationError).message, 'AI unavailable');
    });
  });

  group('reset', () {
    test('returns to Idle from a Success state', () async {
      const result = AiGenerationResult(items: []);
      when(
        () => useCase(tRequest),
      ).thenAnswer((_) async => const Right(result));
      await notifier.generate(tRequest);
      expect(notifier.state, isA<AiGenerationSuccess>());

      notifier.reset();

      expect(notifier.state, isA<AiGenerationIdle>());
    });

    test('returns to Idle from an Error state', () async {
      when(
        () => useCase(tRequest),
      ).thenAnswer((_) async => const Left(ServerFailure('AI unavailable')));
      await notifier.generate(tRequest);
      expect(notifier.state, isA<AiGenerationError>());

      notifier.reset();

      expect(notifier.state, isA<AiGenerationIdle>());
    });
  });
}
