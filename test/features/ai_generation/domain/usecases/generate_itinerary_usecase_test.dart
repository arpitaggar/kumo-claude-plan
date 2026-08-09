import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/ai_generation/domain/entities/ai_generation_request.dart';
import 'package:kumo_claude/features/ai_generation/domain/entities/ai_generation_result.dart';
import 'package:kumo_claude/features/ai_generation/domain/repositories/ai_generation_repository.dart';
import 'package:kumo_claude/features/ai_generation/domain/usecases/generate_itinerary_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockAiGenerationRepository extends Mock
    implements AiGenerationRepository {}

void main() {
  late MockAiGenerationRepository mockRepo;
  late GenerateItineraryUseCase useCase;

  final tRequest = AiGenerationRequest(
    destination: 'Chiang Mai',
    startDate: DateTime.utc(2026, 9),
    endDate: DateTime.utc(2026, 9, 7),
    travelStyle: TravelStyle.adventure,
  );

  const tResult = AiGenerationResult(items: []);

  setUpAll(() {
    registerFallbackValue(
      AiGenerationRequest(
        destination: '',
        startDate: DateTime.utc(2026),
        endDate: DateTime.utc(2026),
        travelStyle: TravelStyle.adventure,
      ),
    );
  });

  setUp(() {
    mockRepo = MockAiGenerationRepository();
    useCase = GenerateItineraryUseCase(mockRepo);
  });

  test('delegates to repository with the given request', () async {
    when(
      () => mockRepo.generateItinerary(tRequest),
    ).thenAnswer((_) async => const Right(tResult));

    final result = await useCase(tRequest);

    verify(() => mockRepo.generateItinerary(tRequest)).called(1);
    result.fold(
      (_) => fail('expected Right'),
      (generated) => expect(generated, tResult),
    );
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.generateItinerary(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('AI request failed')));

    final result = await useCase(tRequest);

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
