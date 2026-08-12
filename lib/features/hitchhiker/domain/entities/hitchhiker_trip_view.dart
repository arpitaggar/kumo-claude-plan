import 'package:equatable/equatable.dart';

/// The read-only trip bundle a Hitchhiker sees, returned by the
/// `hitchhiker_get_trip_view` RPC (stage45_hitchhikers.sql).
///
/// Deliberately minimal — NOT the full itinerary row Captain/Crew get via
/// normal RLS. No `members` (other travelers' identities) and no
/// `expense_summary` (financial data) are ever included. See that RPC's own
/// comment for why.
class HitchhikerTripView extends Equatable {
  const HitchhikerTripView({
    required this.hitchhikerId,
    required this.displayName,
    required this.itineraryId,
    required this.tripTitle,
    required this.tripDescription,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.messages,
    required this.suggestions,
  });

  /// This Hitchhiker's own id and name (so the client knows "who am I" —
  /// there's no session/JWT to derive it from otherwise).
  final String hitchhikerId;
  final String displayName;

  final String itineraryId;
  final String tripTitle;
  final String? tripDescription;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;

  final List<HitchhikerMessage> messages;
  final List<HitchhikerSuggestion> suggestions;

  @override
  List<Object?> get props => [
    hitchhikerId,
    displayName,
    itineraryId,
    tripTitle,
    tripDescription,
    startDate,
    endDate,
    status,
    messages,
    suggestions,
  ];
}

class HitchhikerMessage extends Equatable {
  const HitchhikerMessage({
    required this.id,
    required this.senderName,
    required this.content,
    required this.createdAt,
    required this.isYou,
  });

  final String id;
  final String senderName;
  final String content;
  final DateTime createdAt;

  /// True when this message was sent by the same Hitchhiker viewing it —
  /// computed server-side (hitchhiker_id = the caller's own row), since
  /// there's no auth.uid() on this side to compare against client-side.
  final bool isYou;

  @override
  List<Object?> get props => [id, senderName, content, createdAt, isYou];
}

class HitchhikerSuggestion extends Equatable {
  const HitchhikerSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.suggestedByName,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final String suggestedByName;

  /// 'pending' | 'accepted' | 'dismissed'
  final String status;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    suggestedByName,
    status,
    createdAt,
  ];
}
