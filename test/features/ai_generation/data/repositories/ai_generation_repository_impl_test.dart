import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/ai_generation/data/datasources/ai_generation_datasource.dart';
import 'package:kumo_claude/features/ai_generation/data/repositories/ai_generation_repository_impl.dart';
import 'package:kumo_claude/features/ai_generation/domain/entities/ai_generation_request.dart';
import 'package:kumo_claude/features/ai_generation/domain/entities/ai_generation_result.dart';
import 'package:mocktail/mocktail.dart';

class MockAiGenerationDataSource extends Mock
    implements AiGenerationDataSource {}

void main() {
  late MockAiGenerationDataSource dataSource;
  late AiGenerationRepositoryImpl repository;

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
    dataSource = MockAiGenerationDataSource();
    repository = AiGenerationRepositoryImpl(dataSource: dataSource);
  });

  group('generateItinerary', () {
    test('returns Right(result) on success', () async {
      when(
        () => dataSource.generateItinerary(any()),
      ).thenAnswer((_) async => tResult);

      final result = await repository.generateItinerary(tRequest);

      result.fold(
        (_) => fail('expected Right'),
        (generated) => expect(generated, tResult),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.generateItinerary(any()),
      ).thenThrow(ServerException(message: 'AI request failed'));

      final result = await repository.generateItinerary(tRequest);

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps an unexpected exception to UnexpectedFailure', () async {
      when(
        () => dataSource.generateItinerary(any()),
      ).thenThrow(Exception('boom'));

      final result = await repository.generateItinerary(tRequest);

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
