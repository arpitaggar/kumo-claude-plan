import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/profile/domain/entities/notification_preference.dart';

void main() {
  group('NotifCategory.label', () {
    test('maps every known category to a human-readable label', () {
      expect(NotifCategory.label(NotifCategory.tripInvites), 'Trip Invites');
      expect(
        NotifCategory.label(NotifCategory.expenseActivity),
        'Expense Activity',
      );
      expect(NotifCategory.label(NotifCategory.flightAlerts), 'Flight Alerts');
      expect(NotifCategory.label(NotifCategory.collabUpdates), 'Trip Updates');
      expect(NotifCategory.label(NotifCategory.chatMessages), 'Chat Messages');
      expect(
        NotifCategory.label(NotifCategory.marketingEngagement),
        'News & Offers',
      );
    });

    test('falls back to the raw category string for an unknown category', () {
      expect(
        NotifCategory.label('some_future_category'),
        'some_future_category',
      );
    });
  });

  group('NotificationPreference equality', () {
    test('two instances with the same fields are equal', () {
      const a = NotificationPreference(
        channel: NotifChannel.push,
        category: NotifCategory.chatMessages,
        enabled: true,
      );
      const b = NotificationPreference(
        channel: NotifChannel.push,
        category: NotifCategory.chatMessages,
        enabled: true,
      );

      expect(a, b);
    });

    test('instances differing in enabled are not equal', () {
      const a = NotificationPreference(
        channel: NotifChannel.push,
        category: NotifCategory.chatMessages,
        enabled: true,
      );
      const b = NotificationPreference(
        channel: NotifChannel.push,
        category: NotifCategory.chatMessages,
        enabled: false,
      );

      expect(a, isNot(b));
    });
  });
}
