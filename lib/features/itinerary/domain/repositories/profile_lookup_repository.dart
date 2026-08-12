import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/profile_result.dart';

/// Backs the invite-member and privacy-settings flows: looking up other
/// users to invite, and reading/writing the caller's own discoverability.
/// Split out as its own repository (not `UserProfileRepository`, which owns
/// the full profile CRUD) because it's a narrower, invite/search-scoped
/// concern with its own RLS shape (`is_searchable`-gated reads of *other*
/// users' rows).
abstract class ProfileLookupRepository {
  /// Finds a user by exact email, regardless of their searchability setting.
  Future<Either<Failure, ProfileResult?>> findByEmail(String email);

  /// Searches discoverable users by display name prefix.
  /// Only returns users with is_searchable = true. Excludes [excludeIds].
  Future<Either<Failure, List<ProfileResult>>> searchByName(
    String query, {
    List<String> excludeIds = const [],
  });

  /// Updates the current user's discoverability preference.
  Future<Either<Failure, void>> updateSearchability({
    required bool isSearchable,
  });

  /// Fetches the current user's own profile row.
  Future<Either<Failure, ProfileResult?>> getCurrentUserProfile();

  /// Stores a pending invitation for an email not yet registered in Kumo.
  Future<Either<Failure, void>> createPendingInvitation({
    required String itineraryId,
    required String invitedEmail,
    required String role,
  });
}
