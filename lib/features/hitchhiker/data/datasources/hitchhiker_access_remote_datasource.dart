import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/hitchhiker_trip_view.dart';
import '../models/hitchhiker_trip_view_model.dart';

/// Calls the token-authenticated RPCs (stage45_hitchhikers.sql) using
/// whatever Supabase client is configured — deliberately never checks for
/// or requires a signed-in session. A Hitchhiker client is expected to be
/// fully unauthenticated (anon key only); the access token itself is the
/// only credential.
abstract class HitchhikerAccessRemoteDataSource {
  Future<HitchhikerTripView> getTripView(String token);

  Future<void> sendMessage({required String token, required String content});

  Future<void> suggestItem({
    required String token,
    required String title,
    String? description,
  });
}

class HitchhikerAccessRemoteDataSourceImpl
    implements HitchhikerAccessRemoteDataSource {
  const HitchhikerAccessRemoteDataSourceImpl();

  @override
  Future<HitchhikerTripView> getTripView(String token) async {
    try {
      final result = await KumoSupabaseClient.client.rpc(
        'hitchhiker_get_trip_view',
        params: {'p_token': token},
      );
      return hitchhikerTripViewFromJson(result as Map<String, dynamic>);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> sendMessage({
    required String token,
    required String content,
  }) async {
    try {
      await KumoSupabaseClient.client.rpc(
        'hitchhiker_send_message',
        params: {'p_token': token, 'p_content': content},
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> suggestItem({
    required String token,
    required String title,
    String? description,
  }) async {
    try {
      await KumoSupabaseClient.client.rpc(
        'hitchhiker_suggest_item',
        params: {
          'p_token': token,
          'p_title': title,
          if (description != null) 'p_description': description,
        },
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
