import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/gamification/data/models/xp_event_model.dart';

void main() {
  group('XpEventModel.fromJson', () {
    test('parses every field', () {
      final model = XpEventModel.fromJson({
        'id': 'evt-1',
        'user_id': 'user-1',
        'amount': 30,
        'reason': 'Completed a trip',
        'source_type': 'trip_completed',
        'source_id': 'trip-1',
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(model.id, 'evt-1');
      expect(model.userId, 'user-1');
      expect(model.amount, 30);
      expect(model.reason, 'Completed a trip');
      expect(model.sourceType, 'trip_completed');
      expect(model.sourceId, 'trip-1');
      expect(model.createdAt, DateTime.parse('2026-01-01T00:00:00.000Z'));
    });
  });
}
