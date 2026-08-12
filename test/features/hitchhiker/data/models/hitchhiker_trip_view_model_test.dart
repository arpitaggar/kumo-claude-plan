import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/hitchhiker/data/models/hitchhiker_trip_view_model.dart';

void main() {
  test('parses a full hitchhiker_get_trip_view() response', () {
    final json = {
      'hitchhiker_id': 'hh-1',
      'display_name': 'Priya',
      'itinerary': {
        'id': 'trip-1',
        'title': 'Tokyo Trip',
        'description': 'Spring adventure',
        'start_date': '2026-04-01T00:00:00Z',
        'end_date': '2026-04-10T00:00:00Z',
        'status': 'active',
      },
      'messages': [
        {
          'id': 'msg-1',
          'sender_name': 'Alex',
          'content': 'Hey Priya!',
          'created_at': '2026-03-01T12:00:00Z',
          'is_you': false,
        },
        {
          'id': 'msg-2',
          'sender_name': 'Priya',
          'content': 'Hi!',
          'created_at': '2026-03-01T12:05:00Z',
          'is_you': true,
        },
      ],
      'suggestions': [
        {
          'id': 'sug-1',
          'title': "Nonna's",
          'description': 'Great pasta',
          'suggested_by_name': 'Priya',
          'status': 'pending',
          'created_at': '2026-03-02T09:00:00Z',
        },
      ],
    };

    final view = hitchhikerTripViewFromJson(json);

    expect(view.hitchhikerId, 'hh-1');
    expect(view.displayName, 'Priya');
    expect(view.itineraryId, 'trip-1');
    expect(view.tripTitle, 'Tokyo Trip');
    expect(view.tripDescription, 'Spring adventure');
    expect(view.status, 'active');
    expect(view.messages, hasLength(2));
    expect(view.messages[0].senderName, 'Alex');
    expect(view.messages[0].isYou, isFalse);
    expect(view.messages[1].isYou, isTrue);
    expect(view.suggestions, hasLength(1));
    expect(view.suggestions[0].title, "Nonna's");
    expect(view.suggestions[0].status, 'pending');
  });

  test('handles null description/dates and empty messages/suggestions', () {
    final json = {
      'hitchhiker_id': 'hh-1',
      'display_name': 'Priya',
      'itinerary': {
        'id': 'trip-1',
        'title': 'Tokyo Trip',
        'description': null,
        'start_date': null,
        'end_date': null,
        'status': 'draft',
      },
      'messages': <dynamic>[],
      'suggestions': <dynamic>[],
    };

    final view = hitchhikerTripViewFromJson(json);

    expect(view.tripDescription, isNull);
    expect(view.startDate, isNull);
    expect(view.endDate, isNull);
    expect(view.messages, isEmpty);
    expect(view.suggestions, isEmpty);
  });
}
