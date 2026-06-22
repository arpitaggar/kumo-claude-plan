import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/packing_item_model.dart';

abstract class PackingRemoteDataSource {
  Stream<List<PackingItemModel>> watchItems(String itineraryId);
  Future<PackingItemModel> addItem(PackingItemModel item);
  Future<void> toggleItem(String id, {required bool isChecked});
  Future<void> deleteItem(String id);
}

class PackingRemoteDataSourceImpl implements PackingRemoteDataSource {
  const PackingRemoteDataSourceImpl();

  static const _table = 'packing_items';

  @override
  Stream<List<PackingItemModel>> watchItems(String itineraryId) =>
      KumoSupabaseClient.client
          .from(_table)
          .stream(primaryKey: ['id'])
          .eq('itinerary_id', itineraryId)
          .order('created_at')
          .map((rows) => rows.map(PackingItemModel.fromJson).toList());

  @override
  Future<PackingItemModel> addItem(PackingItemModel item) async {
    try {
      final row = await KumoSupabaseClient.client
          .from(_table)
          .insert(item.toJson())
          .select()
          .single();
      return PackingItemModel.fromJson(row);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> toggleItem(String id, {required bool isChecked}) async {
    try {
      await KumoSupabaseClient.client
          .from(_table)
          .update({'is_checked': isChecked})
          .eq('id', id);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> deleteItem(String id) async {
    try {
      await KumoSupabaseClient.client
          .from(_table)
          .delete()
          .eq('id', id);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
