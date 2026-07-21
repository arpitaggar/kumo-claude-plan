import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/notification_preference_model.dart';
import '../models/user_profile_model.dart';

abstract class UserProfileRemoteDataSource {
  Future<UserProfileModel> getOwnProfile();

  Future<UserProfileModel> updateProfile({
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

  Future<List<NotificationPreferenceModel>> getNotificationPreferences();

  Future<void> upsertNotificationPreference({
    required String channel,
    required String category,
    required bool enabled,
  });
}

class UserProfileRemoteDataSourceImpl implements UserProfileRemoteDataSource {
  const UserProfileRemoteDataSourceImpl();

  static const _cols =
      'id, email, display_name, username, avatar_url, bio, city, country, '
      'timezone, preferred_currency, preferred_language, units_preference, '
      'travel_preference_tags, profile_visibility, contact_visibility, '
      'is_searchable, username_last_changed_at, updated_at';

  @override
  Future<UserProfileModel> getOwnProfile() async {
    final uid = KumoSupabaseClient.auth.currentUser?.id;
    if (uid == null) {
      throw AuthException(message: 'Not authenticated');
    }
    try {
      final rows = await KumoSupabaseClient.client
          .from('profiles')
          .select(_cols)
          .eq('id', uid)
          .limit(1);

      if (rows.isEmpty) {
        throw ServerException(message: 'Profile not found');
      }
      return UserProfileModel.fromJson(rows.first);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<UserProfileModel> updateProfile({
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
  }) async {
    if (KumoSupabaseClient.auth.currentUser == null) {
      throw AuthException(message: 'Not authenticated');
    }
    try {
      // Only include non-null fields — the RPC uses COALESCE so omitted params
      // leave the corresponding column untouched.
      final params = <String, dynamic>{};
      if (displayName != null) {
        params['p_display_name'] = displayName;
      }
      if (username != null) {
        params['p_username'] = username;
      }
      if (bio != null) {
        params['p_bio'] = bio;
      }
      if (city != null) {
        params['p_city'] = city;
      }
      if (country != null) {
        params['p_country'] = country;
      }
      if (timezone != null) {
        params['p_timezone'] = timezone;
      }
      if (preferredCurrency != null) {
        params['p_preferred_currency'] = preferredCurrency;
      }
      if (preferredLanguage != null) {
        params['p_preferred_language'] = preferredLanguage;
      }
      if (unitsPreference != null) {
        params['p_units_preference'] = unitsPreference;
      }
      if (travelPreferenceTags != null) {
        params['p_travel_tags'] = travelPreferenceTags;
      }
      if (profileVisibility != null) {
        params['p_profile_visibility'] = profileVisibility;
      }
      if (contactVisibility != null) {
        params['p_contact_visibility'] = contactVisibility;
      }
      if (avatarUrl != null) {
        params['p_avatar_url'] = avatarUrl;
      }

      await KumoSupabaseClient.client.rpc('update_profile', params: params);
      return getOwnProfile();
    } on sb.PostgrestException catch (e) {
      // The RPC raises human-readable messages for username validation failures
      // (already taken, cooldown, bad format) — surface them directly.
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<NotificationPreferenceModel>> getNotificationPreferences() async {
    final uid = KumoSupabaseClient.auth.currentUser?.id;
    if (uid == null) {
      throw AuthException(message: 'Not authenticated');
    }
    try {
      final rows = await KumoSupabaseClient.client
          .from('notification_preferences')
          .select('channel, category, enabled')
          .eq('user_id', uid);

      return rows.map(NotificationPreferenceModel.fromJson).toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> upsertNotificationPreference({
    required String channel,
    required String category,
    required bool enabled,
  }) async {
    if (KumoSupabaseClient.auth.currentUser == null) {
      throw AuthException(message: 'Not authenticated');
    }
    try {
      await KumoSupabaseClient.client.rpc(
        'upsert_notification_preference',
        params: {
          'p_channel': channel,
          'p_category': category,
          'p_enabled': enabled,
        },
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw UnexpectedException(message: e.toString());
    }
  }
}
