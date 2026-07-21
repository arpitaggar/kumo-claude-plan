import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/notification_preference.dart';
import '../entities/user_profile.dart';

abstract class UserProfileRepository {
  /// Fetches the authenticated user's own full profile from the profiles table.
  Future<Either<Failure, UserProfile>> getOwnProfile();

  /// Calls the `update_profile` RPC to atomically update any subset of fields.
  /// Only non-null arguments are written; null means "leave unchanged".
  /// Throws [ServerFailure] with a user-facing message for:
  ///   - Username already taken
  ///   - Username cooldown (7 days between changes)
  ///   - Invalid username format
  Future<Either<Failure, UserProfile>> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? city,
    String? country,
    String? timezone,
    String? preferredCurrency,
    String? preferredLanguage,
    String? unitsPreference,
    List<String>? travelPreferenceTags,
    String? profileVisibility,
    String? contactVisibility,
    String? avatarUrl,
  });

  /// Returns all notification preference rows for the authenticated user.
  Future<Either<Failure, List<NotificationPreference>>> getNotificationPreferences();

  /// Upserts a single (channel, category) preference row.
  Future<Either<Failure, void>> upsertNotificationPreference({
    required String channel,
    required String category,
    required bool enabled,
  });
}
