import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/xp_event_model.dart';

abstract class GamificationRemoteDataSource {
  Future<List<XpEventModel>> fetchXpEvents(String userId);
}

class GamificationRemoteDataSourceImpl implements GamificationRemoteDataSource {
  const GamificationRemoteDataSourceImpl();

  static const _table = 'xp_events';

  /// Defensive cap, not a real pagination limit — real per-user volume is
  /// expected to stay in the dozens-to-low-hundreds for a long time (six
  /// award sources, no expense-farming vector, dedup blocks re-awarding the
  /// same event). Both the summary total/level and the "recent activity"
  /// list are derived client-side from this one fetch.
  static const _fetchLimit = 500;

  @override
  Future<List<XpEventModel>> fetchXpEvents(String userId) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(_fetchLimit);
      return rows.map(XpEventModel.fromJson).toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
