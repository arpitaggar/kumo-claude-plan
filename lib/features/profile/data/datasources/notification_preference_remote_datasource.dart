import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/notification_preference_model.dart';

abstract class NotificationPreferenceRemoteDataSource {
  Future<List<NotificationPreferenceModel>> getNotificationPreferences();

  Future<void> upsertNotificationPreference({
    required String channel,
    required String category,
    required bool enabled,
  });
}

class NotificationPreferenceRemoteDataSourceImpl
    implements NotificationPreferenceRemoteDataSource {
  const NotificationPreferenceRemoteDataSourceImpl();

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
