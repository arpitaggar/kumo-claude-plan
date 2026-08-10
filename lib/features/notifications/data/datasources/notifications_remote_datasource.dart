import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/app_notification_model.dart';

abstract class NotificationsRemoteDataSource {
  Stream<List<AppNotificationModel>> watchNotifications(String userId);
  Future<void> markAllRead(String userId);
}

class NotificationsRemoteDataSourceImpl
    implements NotificationsRemoteDataSource {
  const NotificationsRemoteDataSourceImpl();

  static const _table = 'notifications';

  /// Backs the activity feed page, the unread badge, and the foreground
  /// local-notification watcher — not a fully paginated history. 50 is
  /// generous for any of those three uses; deeper history isn't needed yet
  /// (same "trim scope, note it" call as social feed pagination elsewhere).
  static const _streamLimit = 50;

  @override
  Stream<List<AppNotificationModel>> watchNotifications(String userId) =>
      KumoSupabaseClient.client
          .from(_table)
          .stream(primaryKey: ['id'])
          .eq('recipient_id', userId)
          .order('created_at')
          .limit(_streamLimit)
          .map((rows) {
            // `.order()` only reliably sorts the initial snapshot — rows
            // re-emitted after a realtime insert/update aren't guaranteed to
            // stay sorted (same caveat as ChatRemoteDataSourceImpl
            // .watchMessages). Sorted newest-first here since that's how
            // every consumer (feed page, badge count, watcher's "is the top
            // item new" check) wants it, unlike chat's oldest-first.
            final notifications =
                rows.map(AppNotificationModel.fromJson).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return notifications;
          });

  @override
  Future<void> markAllRead(String userId) async {
    try {
      await KumoSupabaseClient.client
          .from(_table)
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('recipient_id', userId)
          .isFilter('read_at', null);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
