import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../itinerary/domain/entities/transport_mode.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../domain/entities/ai_generated_segment.dart';
import '../../domain/entities/ai_generation_request.dart';
import '../../domain/entities/ai_generation_result.dart';

// ignore: one_member_abstracts
abstract class AiGenerationDataSource {
  Future<AiGenerationResult> generateItinerary(AiGenerationRequest request);
}

class AiGenerationDataSourceImpl implements AiGenerationDataSource {
  const AiGenerationDataSourceImpl();

  static const _uuid = Uuid();

  @override
  Future<AiGenerationResult> generateItinerary(
      AiGenerationRequest request) async {
    try {
      final response = await KumoSupabaseClient.client.functions.invoke(
        'generate-itinerary',
        body: {
          'destination': request.destination,
          'trip_days': request.tripDays,
          'travel_style': request.travelStyle.label,
          if (request.interests != null && request.interests!.isNotEmpty)
            'interests': request.interests,
          'start_date':
              request.startDate.toIso8601String().substring(0, 10),
          'end_date': request.endDate.toIso8601String().substring(0, 10),
        },
      );

      final data = response.data as Map<String, dynamic>?;

      if (data == null || data['error'] != null) {
        throw ServerException(
          message: data?['error'] as String? ?? 'AI generation failed',
        );
      }

      final rawItems = data['items'] as List<dynamic>?;
      if (rawItems == null) {
        throw ServerException(message: 'Empty response from AI');
      }
      final rawSegments = data['segments'] as List<dynamic>? ?? [];

      return AiGenerationResult(
        items: parseItems(rawItems, request.startDate),
        segments: parseSegments(rawSegments),
      );
    } on FunctionException catch (e) {
      throw ServerException(message: 'AI generation failed: ${e.reasonPhrase}');
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw UnexpectedException(message: e.toString());
    }
  }

  // ignore: prefer_constructors_over_static_methods
  static List<ItineraryItem> parseItems(List<dynamic> raw, DateTime tripStart) =>
      raw.map((e) {
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

  // ignore: prefer_constructors_over_static_methods
  static List<AiGeneratedSegment> parseSegments(List<dynamic> raw) =>
      raw
          .map((e) {
            final map = e as Map<String, dynamic>;
            final origin = map['origin'] as String?;
            final destination = map['destination'] as String?;
            // Skip malformed entries rather than failing the whole response
            // over one bad leg.
            if (origin == null || destination == null) {
              return null;
            }

            final modeStr = map['mode'] as String? ?? 'other';
            final mode = TransportMode.values.firstWhere(
              (m) => m.name == modeStr,
              orElse: () => TransportMode.other,
            );

            return AiGeneratedSegment(
              mode: mode,
              originName: origin,
              destinationName: destination,
              departureTime: _tryParseUtc(map['departure_time'] as String?),
              arrivalTime: _tryParseUtc(map['arrival_time'] as String?),
            );
          })
          .whereType<AiGeneratedSegment>()
          .toList();

  static DateTime? _tryParseUtc(String? raw) {
    if (raw == null) {
      return null;
    }
    try {
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return null;
    }
  }
}
