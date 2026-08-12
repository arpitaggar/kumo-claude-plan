import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/profile/data/models/notification_preference_model.dart';

void main() {
  group('NotificationPreferenceModel.fromJson', () {
    test('parses channel/category/enabled', () {
      final model = NotificationPreferenceModel.fromJson(const {
        'channel': 'push',
        'category': 'trip_invites',
        'enabled': true,
      });

      expect(model.channel, 'push');
      expect(model.category, 'trip_invites');
      expect(model.enabled, isTrue);
    });

    test('parses enabled: false', () {
      final model = NotificationPreferenceModel.fromJson(const {
        'channel': 'email',
        'category': 'marketing_engagement',
        'enabled': false,
      });

      expect(model.enabled, isFalse);
    });
  });
}
