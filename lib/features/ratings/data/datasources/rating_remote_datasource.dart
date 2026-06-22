import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exception.dart';
import '../models/rating_model.dart';

abstract class RatingRemoteDataSource {
  Stream<List<RatingModel>> watchRatings(String itineraryId);
  Future<RatingModel> addRating(RatingModel rating);
  Future<void> deleteRating(String ratingId);
}

class RatingRemoteDataSourceImpl implements RatingRemoteDataSource {
  const RatingRemoteDataSourceImpl();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Stream<List<RatingModel>> watchRatings(String itineraryId) => _client
      .from('ratings')
      .stream(primaryKey: ['id'])
      .eq('itinerary_id', itineraryId)
      .order('created_at')
      .map((rows) => rows.map(RatingModel.fromJson).toList());

  @override
  Future<RatingModel> addRating(RatingModel rating) async {
    try {
      final rows = await _client
          .from('ratings')
          .insert(rating.toJson())
          .select();
      return RatingModel.fromJson(rows.first);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteRating(String ratingId) async {
    try {
      await _client.from('ratings').delete().eq('id', ratingId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
