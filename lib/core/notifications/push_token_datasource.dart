import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../error/exception.dart';
import '../network/supabase_client.dart';

/// Registers/refreshes this device's FCM token via the `upsert_push_token`
/// RPC. Moved out of `chat`'s datasource — push-token registration has
/// nothing to do with chat messages, it just historically lived there
/// because chat was the first (and, before this, only) push consumer.
abstract class PushTokenDataSource {
  Future<void> upsertPushToken({
    required String token,
    required String platform,
  });
}

class PushTokenDataSourceImpl implements PushTokenDataSource {
  const PushTokenDataSourceImpl();

  @override
  Future<void> upsertPushToken({
    required String token,
    required String platform,
  }) async {
    try {
      await KumoSupabaseClient.client.rpc(
        'upsert_push_token',
        params: {'p_token': token, 'p_platform': platform},
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
