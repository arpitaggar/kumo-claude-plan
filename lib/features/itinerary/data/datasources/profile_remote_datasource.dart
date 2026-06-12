import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';

class ProfileResult {
  const ProfileResult({
    required this.id,
    required this.displayName,
    required this.email,
    required this.isSearchable,
    this.avatarUrl,
  });

  factory ProfileResult.fromRow(Map<String, dynamic> row) => ProfileResult(
        id: row['id'] as String,
        displayName: (row['display_name'] as String?) ?? '',
        email: row['email'] as String,
        isSearchable: (row['is_searchable'] as bool?) ?? true,
        avatarUrl: row['avatar_url'] as String?,
      );

  final String id;
  final String displayName;
  final String email;
  final bool isSearchable;
  final String? avatarUrl;
}

// ignore: one_member_abstracts
abstract class ProfileRemoteDataSource {
  /// Finds a user by exact email, regardless of their searchability setting.
  Future<ProfileResult?> findByEmail(String email);

  /// Searches discoverable users by display name prefix.
  /// Only returns users with is_searchable = true. Excludes [excludeIds].
  Future<List<ProfileResult>> searchByName(
    String query, {
    List<String> excludeIds = const [],
  });

  /// Updates the current user's discoverability preference.
  Future<void> updateSearchability({required bool isSearchable});

  /// Fetches the current user's own profile row.
  Future<ProfileResult?> getCurrentUserProfile();

  /// Stores a pending invitation for an email not yet registered in Kumo.
  Future<void> createPendingInvitation({
    required String itineraryId,
    required String invitedEmail,
    required String role,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  const ProfileRemoteDataSourceImpl();

  static const _cols = 'id, display_name, email, avatar_url, is_searchable';

  @override
  Future<ProfileResult?> findByEmail(String email) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from('profiles')
          .select(_cols)
          .eq('email', email.trim().toLowerCase())
          .limit(1);

      return rows.isEmpty ? null : ProfileResult.fromRow(rows.first);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<ProfileResult>> searchByName(
    String query, {
    List<String> excludeIds = const [],
  }) async {
    if (query.trim().length < 2) {
      return [];
    }
    try {
      final currentUid = KumoSupabaseClient.auth.currentUser?.id;
      final excluded = <String>{...excludeIds, ?currentUid};

      // Fetch all filters before .limit() to stay on PostgrestFilterBuilder.
      // Client-side exclusion is safe here — results are already capped at 20.
      final rows = await KumoSupabaseClient.client
          .from('profiles')
          .select(_cols)
          .eq('is_searchable', true)
          .ilike('display_name', '%${query.trim()}%')
          .limit(20);

      return rows
          .map(ProfileResult.fromRow)
          .where((p) => !excluded.contains(p.id))
          .toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> updateSearchability({required bool isSearchable}) async {
    final uid = KumoSupabaseClient.auth.currentUser?.id;
    if (uid == null) {
      throw AuthException(message: 'Not authenticated');
    }
    try {
      await KumoSupabaseClient.client
          .from('profiles')
          .update({'is_searchable': isSearchable})
          .eq('id', uid);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<ProfileResult?> getCurrentUserProfile() async {
    final uid = KumoSupabaseClient.auth.currentUser?.id;
    if (uid == null) {
      return null;
    }
    try {
      final rows = await KumoSupabaseClient.client
          .from('profiles')
          .select(_cols)
          .eq('id', uid)
          .limit(1);

      return rows.isEmpty ? null : ProfileResult.fromRow(rows.first);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> createPendingInvitation({
    required String itineraryId,
    required String invitedEmail,
    required String role,
  }) async {
    final uid = KumoSupabaseClient.auth.currentUser?.id;
    if (uid == null) {
      throw AuthException(message: 'Not authenticated');
    }
    try {
      await KumoSupabaseClient.client.from('pending_invitations').upsert(
        {
          'itinerary_id': itineraryId,
          'invited_email': invitedEmail.trim().toLowerCase(),
          'invited_by': uid,
          'role': role,
        },
        onConflict: 'itinerary_id,invited_email',
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
