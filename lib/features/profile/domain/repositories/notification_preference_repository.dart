import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/notification_preference.dart';

/// Split out of `UserProfileRepository` — notification-preference CRUD is a
/// separable concern from profile CRUD (`NotificationPreferencesPage` never
/// needs the rest of the profile interface, only this).
abstract class NotificationPreferenceRepository {
  /// Returns all notification preference rows for the authenticated user.
  Future<Either<Failure, List<NotificationPreference>>>
  getNotificationPreferences();

  /// Upserts a single (channel, category) preference row.
  Future<Either<Failure, void>> upsertNotificationPreference({
    required String channel,
    required String category,
    required bool enabled,
  });
}
