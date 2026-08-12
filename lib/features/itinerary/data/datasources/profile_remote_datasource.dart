import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/profile_result_model.dart';

// ignore: one_member_abstracts
abstract class ProfileRemoteDataSource {
  /// Finds a user by exact email, regardless of their searchability setting.
  Future<ProfileResultModel?> findByEmail(String email);

  /// Searches discoverable users by display name prefix.
  /// Only returns users with is_searchable = true. Excludes [excludeIds].
  Future<List<ProfileResultModel>> searchByName(
    String query, {
    List<String> excludeIds = const [],
  });

  /// Updates the current user's discoverability preference.
  Future<void> updateSearchability({required bool isSearchable});

  /// Fetches the current user's own profile row.
  Future<ProfileResultModel?> getCurrentUserProfile();

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
  Future<ProfileResultModel?> findByEmail(String email) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from('profiles')
          .select(_cols)
          .eq('email', email.trim().toLowerCase())
          .limit(1);

      return rows.isEmpty ? null : ProfileResultModel.fromRow(rows.first);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<ProfileResultModel>> searchByName(
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
          .map(ProfileResultModel.fromRow)
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
  Future<ProfileResultModel?> getCurrentUserProfile() async {
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

      return rows.isEmpty ? null : ProfileResultModel.fromRow(rows.first);
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
      await KumoSupabaseClient.client.from('pending_invitations').upsert({
        'itinerary_id': itineraryId,
        'invited_email': invitedEmail.trim().toLowerCase(),
        'invited_by': uid,
        'role': role,
      }, onConflict: 'itinerary_id,invited_email');
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }

    // Best-effort email — failure here does not fail the invite.
    try {
      await KumoSupabaseClient.client.functions.invoke(
        'invite-email',
        body: {
          'itinerary_id': itineraryId,
          'invited_email': invitedEmail.trim().toLowerCase(),
          'role': role,
        },
      );
    } catch (_) {
      // Edge function not deployed or Resend not configured — silently skip.
    }
  }
}
