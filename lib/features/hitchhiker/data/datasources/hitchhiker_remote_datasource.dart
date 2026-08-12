import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/hitchhiker_model.dart';

abstract class HitchhikerRemoteDataSource {
  Future<HitchhikerModel> createHitchhiker({
    required String itineraryId,
    required String displayName,
  });

  Future<void> revokeHitchhiker(String hitchhikerId);

  Future<List<HitchhikerModel>> listHitchhikers(String itineraryId);
}

class HitchhikerRemoteDataSourceImpl implements HitchhikerRemoteDataSource {
  const HitchhikerRemoteDataSourceImpl();

  @override
  Future<HitchhikerModel> createHitchhiker({
    required String itineraryId,
    required String displayName,
  }) async {
    try {
      final rows = await KumoSupabaseClient.client.rpc(
        'create_hitchhiker',
        params: {'p_itinerary_id': itineraryId, 'p_display_name': displayName},
      );
      final row = (rows as List).first as Map<String, dynamic>;
      return HitchhikerModel(
        id: row['id'] as String,
        itineraryId: itineraryId,
        displayName: displayName,
        accessToken: row['access_token'] as String,
        createdAt: DateTime.now(),
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> revokeHitchhiker(String hitchhikerId) async {
    try {
      await KumoSupabaseClient.client.rpc(
        'revoke_hitchhiker',
        params: {'p_hitchhiker_id': hitchhikerId},
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<HitchhikerModel>> listHitchhikers(String itineraryId) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from('trip_hitchhikers')
          .select()
          .eq('itinerary_id', itineraryId)
          .order('created_at');
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(HitchhikerModel.fromJson)
          .toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
