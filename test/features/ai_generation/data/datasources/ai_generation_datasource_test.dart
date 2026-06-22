import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/features/ai_generation/data/datasources/ai_generation_datasource.dart';
import 'package:kumo_claude/features/ai_generation/domain/entities/ai_generation_request.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AiGenerationDataSourceImpl dataSource;

  final request = AiGenerationRequest(
    destination: 'Tokyo',
    startDate: DateTime.utc(2026, 6, 10),
    endDate: DateTime.utc(2026, 6, 12),
    travelStyle: TravelStyle.culture,
  );

  setUp(() {
    mockDio = MockDio();
    dataSource = AiGenerationDataSourceImpl(dio: mockDio);
  });

  Response<Map<String, dynamic>> makeResponse(String text) => Response(
        data: {
          'content': [
            {'type': 'text', 'text': text}
          ]
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: '/messages'),
      );

  group('AiGenerationDataSourceImpl.generateItinerary', () {
    test('parses a valid JSON array from AI response', () async {
      const json = '''
[
  {
    "item_type": "activity",
    "title": "Visit Senso-ji Temple",
    "start_time": "2026-06-10T09:00:00Z",
    "end_time": "2026-06-10T11:00:00Z",
    "location": "Asakusa, Tokyo"
  },
  {
    "item_type": "restaurant",
    "title": "Ramen lunch",
    "start_time": "2026-06-10T12:30:00Z",
    "end_time": "2026-06-10T13:30:00Z",
    "location": null
  }
]''';
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => makeResponse(json));

      final items = await dataSource.generateItinerary(request);

      expect(items, hasLength(2));
      expect(items[0].title, 'Visit Senso-ji Temple');
      expect(items[0].itemType, 'activity');
      expect(items[0].location, 'Asakusa, Tokyo');
      expect(items[1].title, 'Ramen lunch');
      expect(items[1].location, isNull);
    });

    test('strips markdown fences and still parses JSON', () async {
      const json = '''
```json
[
  {
    "item_type": "hotel",
    "title": "Check in to Shinjuku hotel",
    "start_time": "2026-06-10T15:00:00Z",
    "end_time": null,
    "location": "Shinjuku"
  }
]
```''';
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => makeResponse(json));

      final items = await dataSource.generateItinerary(request);

      expect(items, hasLength(1));
      expect(items[0].title, 'Check in to Shinjuku hotel');
      expect(items[0].endTime, isNull);
    });

    test('items are sorted by startTime ascending', () async {
      const json = '''
[
  {
    "item_type": "activity",
    "title": "Evening walk",
    "start_time": "2026-06-10T19:00:00Z",
    "end_time": null,
    "location": null
  },
  {
    "item_type": "activity",
    "title": "Morning yoga",
    "start_time": "2026-06-10T07:00:00Z",
    "end_time": null,
    "location": null
  }
]''';
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => makeResponse(json));

      final items = await dataSource.generateItinerary(request);

      expect(items[0].title, 'Morning yoga');
      expect(items[1].title, 'Evening walk');
    });

    test('falls back to tripStart when start_time is missing', () async {
      const json = '''
[
  {
    "item_type": "activity",
    "title": "Free time",
    "start_time": null,
    "end_time": null,
    "location": null
  }
]''';
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => makeResponse(json));

      final items = await dataSource.generateItinerary(request);

      expect(items, hasLength(1));
      expect(items[0].startTime, request.startDate.toUtc());
    });

    test('throws ServerException when content is empty', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            data: {'content': []},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/messages'),
          ));

      expect(
        () => dataSource.generateItinerary(request),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws ServerException when JSON cannot be parsed', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => makeResponse('This is not JSON at all.'));

      expect(
        () => dataSource.generateItinerary(request),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws ServerException on DioException', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/messages'),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(
        () => dataSource.generateItinerary(request),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
