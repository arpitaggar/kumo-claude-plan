import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../error/exception.dart';
import '../network/supabase_client.dart';
import 'profile_status.dart';

abstract class ProfileStatusDataSource {
  /// The signed-in user's current premium status (the latest logged row).
  /// Closes an expired trial/grant first (see close_expired_premium_status
  /// in stage21_trip_segments.sql) so the result — and the log itself — stay
  /// accurate without needing a cron job.
  Future<ProfileStatus?> fetchCurrent();
}

class ProfileStatusDataSourceImpl implements ProfileStatusDataSource {
  const ProfileStatusDataSourceImpl();

  static const _table = 'profile_status';

  @override
  Future<ProfileStatus?> fetchCurrent() async {
    try {
      try {
        await KumoSupabaseClient.client.rpc('close_expired_premium_status');
      } on sb.PostgrestException {
        // Best-effort — a failed expiry-close shouldn't block reading status.
      }

      final rows = await KumoSupabaseClient.client
          .from(_table)
          .select()
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) {
        return null;
      }
      return ProfileStatus.fromJson(rows.first);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
