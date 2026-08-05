import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/user_profile_remote_datasource.dart';
import '../../data/repositories/user_profile_repository_impl.dart';
import '../../domain/entities/notification_preference.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

// ── Infrastructure ──────────────────────────────────────────────────────────

final userProfileRemoteDataSourceProvider =
    Provider<UserProfileRemoteDataSource>(
  (_) => const UserProfileRemoteDataSourceImpl(),
);

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepositoryImpl(
    ref.watch(userProfileRemoteDataSourceProvider),
  ),
);

// ── Own profile ─────────────────────────────────────────────────────────────

/// Full profile row for the authenticated user.
/// Invalidate with [ref.invalidate(userProfileProvider)] after any update.
final userProfileProvider = FutureProvider.autoDispose<UserProfile?>((ref) async {
  final result = await ref.read(userProfileRepositoryProvider).getOwnProfile();
  return result.fold((_) => null, (profile) => profile);
});

// ── Other users' profiles ───────────────────────────────────────────────────

/// Full profile row for a user other than the caller, e.g. for viewing a
/// post author's public profile page.
final profileByIdProvider =
    FutureProvider.autoDispose.family<UserProfile?, String>((ref, userId) async {
  final result =
      await ref.read(userProfileRepositoryProvider).getProfileById(userId);
  return result.fold((_) => null, (profile) => profile);
});

// ── Notification preferences ─────────────────────────────────────────────────

final notificationPreferencesProvider =
    FutureProvider.autoDispose<List<NotificationPreference>>((ref) async {
  final result = await ref
      .read(userProfileRepositoryProvider)
      .getNotificationPreferences();
  return result.fold((_) => [], (prefs) => prefs);
});
