import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/trip_segment_model.dart';

abstract class TripSegmentRemoteDataSource {
  Stream<List<TripSegmentModel>> watchSegments(String itineraryId);
  Future<TripSegmentModel> addSegment(TripSegmentModel model);
  Future<TripSegmentModel> updateSegment(TripSegmentModel model);
  Future<void> deleteSegment(String segmentId);
  Future<void> reorderSegments(List<TripSegmentModel> reordered);
}

class TripSegmentRemoteDataSourceImpl implements TripSegmentRemoteDataSource {
  const TripSegmentRemoteDataSourceImpl();

  static const _table = 'trip_segments';

  @override
  Stream<List<TripSegmentModel>> watchSegments(String itineraryId) =>
      KumoSupabaseClient.client
          .from(_table)
          .stream(primaryKey: ['id'])
          .eq('itinerary_id', itineraryId)
          .order('order_index')
          .map((rows) => rows.map(TripSegmentModel.fromJson).toList());

  @override
  Future<TripSegmentModel> addSegment(TripSegmentModel model) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from(_table)
          .insert(model.toJson())
          .select();
      return TripSegmentModel.fromJson(rows.first);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<TripSegmentModel> updateSegment(TripSegmentModel model) async {
    try {
      final rows = await KumoSupabaseClient.client
          .from(_table)
          .update(model.toJson())
          .eq('id', model.id)
          .select();
      return TripSegmentModel.fromJson(rows.first);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> deleteSegment(String segmentId) async {
    try {
      await KumoSupabaseClient.client
          .from(_table)
          .delete()
          .eq('id', segmentId);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> reorderSegments(List<TripSegmentModel> reordered) async {
    try {
      await KumoSupabaseClient.client
          .from(_table)
          .upsert(reordered.map((m) => m.toJson()).toList());
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
