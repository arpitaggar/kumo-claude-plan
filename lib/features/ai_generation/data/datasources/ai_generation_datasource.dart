import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../../config/environment.dart';
import '../../../../core/error/exception.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../domain/entities/ai_generation_request.dart';

// ignore: one_member_abstracts
abstract class AiGenerationDataSource {
  Future<List<ItineraryItem>> generateItinerary(AiGenerationRequest request);
}

class AiGenerationDataSourceImpl implements AiGenerationDataSource {
  AiGenerationDataSourceImpl({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.anthropic.com/v1',
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'x-api-key': Environment.anthropicApiKey,
                'anthropic-version': '2023-06-01',
                'content-type': 'application/json',
              },
            ));

  final Dio _dio;

  static const _model = 'claude-haiku-4-5-20251001';
  static const _uuid = Uuid();

  @override
  Future<List<ItineraryItem>> generateItinerary(
      AiGenerationRequest request) async {
    final prompt = _buildPrompt(request);

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/messages',
        data: {
          'model': _model,
          'max_tokens': 2048,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        },
      );

      final text =
          (response.data?['content'] as List?)?.firstOrNull?['text'] as String?;
      if (text == null) {
        throw ServerException(message: 'Empty response from AI');
      }

      return _parseItems(text, request.startDate);
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] as String?;
      throw ServerException(
          message: msg ?? 'AI generation failed: ${e.message}');
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw UnexpectedException(message: e.toString());
    }
  }

  String _buildPrompt(AiGenerationRequest request) {
    final interests = request.interests?.isNotEmpty == true
        ? '\nSpecific interests: ${request.interests}'
        : '';
    return '''
Generate a ${request.tripDays}-day travel itinerary for ${request.destination}.
Travel style: ${request.travelStyle.label}$interests
Trip dates: ${request.startDate.toIso8601String().substring(0, 10)} to ${request.endDate.toIso8601String().substring(0, 10)}

Return ONLY a valid JSON array — no markdown, no explanation. Each element must have exactly these fields:
{
  "item_type": "activity" | "flight" | "hotel" | "restaurant" | "transport",
  "title": "string",
  "start_time": "ISO 8601 datetime in UTC, e.g. 2026-06-10T09:00:00Z",
  "end_time": "ISO 8601 datetime in UTC or null",
  "location": "string or null"
}

Schedule 3-5 items per day, spread across realistic times. Use the actual trip dates.
''';
  }

  List<ItineraryItem> _parseItems(String text, DateTime tripStart) {
    final cleaned = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final raw = _decodeJsonArray(cleaned);
    if (raw == null) {
      throw ServerException(message: 'Could not parse AI response as JSON');
    }

    return raw.map((e) {
      final map = e as Map<String, dynamic>;
      final startRaw = map['start_time'] as String?;
      final endRaw = map['end_time'] as String?;

      DateTime startTime;
      try {
        startTime = startRaw != null
            ? DateTime.parse(startRaw).toUtc()
            : tripStart.toUtc();
      } catch (_) {
        startTime = tripStart.toUtc();
      }

      DateTime? endTime;
      if (endRaw != null) {
        try {
          endTime = DateTime.parse(endRaw).toUtc();
        } catch (_) {
          endTime = null;
        }
      }

      return ItineraryItem(
        id: _uuid.v4(),
        itemType: map['item_type'] as String? ?? 'activity',
        title: map['title'] as String? ?? 'Untitled',
        startTime: startTime,
        endTime: endTime,
        location: map['location'] as String?,
      );
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<dynamic>? _decodeJsonArray(String text) {
    try {
      return jsonDecode(text) as List<dynamic>;
    } catch (_) {
      final match = RegExp(r'\[[\s\S]*\]').firstMatch(text);
      if (match == null) {
        return null;
      }
      try {
        return jsonDecode(match.group(0)!) as List<dynamic>;
      } catch (_) {
        return null;
      }
    }
  }
}
