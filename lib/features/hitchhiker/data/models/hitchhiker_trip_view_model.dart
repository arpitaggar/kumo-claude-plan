import '../../domain/entities/hitchhiker_trip_view.dart';

/// Parses the jsonb bundle returned by `hitchhiker_get_trip_view()`
/// (stage45_hitchhikers.sql) into [HitchhikerTripView].
HitchhikerTripView hitchhikerTripViewFromJson(Map<String, dynamic> json) {
  final itinerary = json['itinerary'] as Map<String, dynamic>;
  final rawMessages = (json['messages'] as List?) ?? const [];
  final rawSuggestions = (json['suggestions'] as List?) ?? const [];

  return HitchhikerTripView(
    hitchhikerId: json['hitchhiker_id'] as String,
    displayName: json['display_name'] as String,
    itineraryId: itinerary['id'] as String,
    tripTitle: itinerary['title'] as String,
    tripDescription: itinerary['description'] as String?,
    startDate: itinerary['start_date'] != null
        ? DateTime.parse(itinerary['start_date'] as String)
        : null,
    endDate: itinerary['end_date'] != null
        ? DateTime.parse(itinerary['end_date'] as String)
        : null,
    status: (itinerary['status'] as String?) ?? 'draft',
    messages: rawMessages
        .cast<Map<String, dynamic>>()
        .map(
          (m) => HitchhikerMessage(
            id: m['id'] as String,
            senderName: (m['sender_name'] as String?) ?? '',
            content: (m['content'] as String?) ?? '',
            createdAt: DateTime.parse(m['created_at'] as String),
            isYou: (m['is_you'] as bool?) ?? false,
          ),
        )
        .toList(),
    suggestions: rawSuggestions
        .cast<Map<String, dynamic>>()
        .map(
          (s) => HitchhikerSuggestion(
            id: s['id'] as String,
            title: (s['title'] as String?) ?? '',
            description: s['description'] as String?,
            suggestedByName: (s['suggested_by_name'] as String?) ?? '',
            status: (s['status'] as String?) ?? 'pending',
            createdAt: DateTime.parse(s['created_at'] as String),
          ),
        )
        .toList(),
  );
}
