import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../itinerary/data/models/itinerary_model.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';

class DiscoverRemoteDataSource {
  const DiscoverRemoteDataSource();

  static const _table = 'itineraries';

  Future<List<ItineraryModel>> fetchPublicItineraries({String? query}) async {
    try {
      final data = await KumoSupabaseClient.client
          .from(_table)
          .select()
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .limit(50);

      var results = (data as List<dynamic>)
          .map((j) => ItineraryModel.fromJson(j as Map<String, dynamic>))
          .toList();

      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        results = results
            .where(
              (m) =>
                  m.title.toLowerCase().contains(q) ||
                  (m.description?.toLowerCase().contains(q) ?? false),
            )
            .toList();
      }

      return results;
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  Future<ItineraryModel> cloneItinerary({
    required String itineraryId,
    required String newOwnerId,
    required String newOwnerName,
  }) async {
    try {
      final original = await KumoSupabaseClient.client
          .from(_table)
          .select()
          .eq('id', itineraryId)
          .single();

      final now = DateTime.now().toUtc();
      final cloned = <String, dynamic>{
        ...Map<String, dynamic>.from(original),
        'id': const Uuid().v4(),
        'owner_id': newOwnerId,
        'members': [
          {
            'user_id': newOwnerId,
            'user_name': newOwnerName,
            'role': GroupMemberRole.owner.name,
            'joined_at': now.toIso8601String(),
          },
        ],
        'is_public': false,
        'notes': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'expense_summary': {
          'total_spent': 0,
          'spent_by_category': <String, dynamic>{},
          'member_balances': <String, dynamic>{},
        },
      };

      final inserted = await KumoSupabaseClient.client
          .from(_table)
          .insert(cloned)
          .select()
          .single();

      return ItineraryModel.fromJson(inserted);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
