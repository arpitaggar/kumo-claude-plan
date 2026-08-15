import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/user_profile.dart';

abstract class UserProfileRepository {
  /// Fetches the authenticated user's own full profile from the profiles table.
  Future<Either<Failure, UserProfile>> getOwnProfile();

  /// Fetches another user's profile by id, for viewing their public profile
  /// page. Backed by the same `profiles_select` RLS policy that already
  /// allows any authenticated user to read any profile row.
  Future<Either<Failure, UserProfile>> getProfileById(String userId);

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
    bool? pushMessagePreviewEnabled,
    List<String>? enabledAccommodationSources,
  });
}
