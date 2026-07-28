import 'package:equatable/equatable.dart';

/// Valid notification channels.
class NotifChannel {
  static const push  = 'push';
  static const email = 'email';
  static const sms   = 'sms';

  static const all = [push, email, sms];
}

/// Valid notification categories.
class NotifCategory {
  static const tripInvites       = 'trip_invites';
  static const expenseActivity   = 'expense_activity';
  static const flightAlerts      = 'flight_alerts';
  static const collabUpdates     = 'collab_updates';
  static const marketingEngagement = 'marketing_engagement';
  static const chatMessages      = 'chat_messages';

  static const all = [
    tripInvites,
    expenseActivity,
    flightAlerts,
    collabUpdates,
    chatMessages,
    marketingEngagement,
  ];

  static String label(String category) => switch (category) {
        tripInvites          => 'Trip Invites',
        expenseActivity      => 'Expense Activity',
        flightAlerts         => 'Flight Alerts',
        collabUpdates        => 'Trip Updates',
        chatMessages         => 'Chat Messages',
        marketingEngagement  => 'News & Offers',
        _                    => category,
      };
}

class NotificationPreference extends Equatable {
  const NotificationPreference({
    required this.channel,
    required this.category,
    required this.enabled,
  });

  final String channel;
  final String category;
  final bool enabled;

  @override
  List<Object?> get props => [channel, category, enabled];
}
