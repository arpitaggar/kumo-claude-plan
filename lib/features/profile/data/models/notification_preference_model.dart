import '../../domain/entities/notification_preference.dart';

class NotificationPreferenceModel extends NotificationPreference {
  const NotificationPreferenceModel({
    required super.channel,
    required super.category,
    required super.enabled,
  });

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) =>
      NotificationPreferenceModel(
        channel:  json['channel']  as String,
        category: json['category'] as String,
        enabled:  json['enabled']  as bool,
      );
}
