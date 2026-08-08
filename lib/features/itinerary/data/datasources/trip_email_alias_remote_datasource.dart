import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/trip_email_alias_model.dart';

abstract class TripEmailAliasRemoteDataSource {
  Future<TripEmailAliasModel> fetchAlias(String itineraryId);
}

class TripEmailAliasRemoteDataSourceImpl
    implements TripEmailAliasRemoteDataSource {
  const TripEmailAliasRemoteDataSourceImpl();

  static const _aliasTable = 'trip_email_aliases';
  static const _configTable = 'app_config';

  @override
  Future<TripEmailAliasModel> fetchAlias(String itineraryId) async {
    try {
      // Two small reads rather than a join — trip_email_domain is a single
      // shared app_config row (see stage21/stage27), not per-trip data.
      final results = await Future.wait([
        KumoSupabaseClient.client
            .from(_aliasTable)
            .select('local_part')
            .eq('itinerary_id', itineraryId)
            .single(),
        KumoSupabaseClient.client
            .from(_configTable)
            .select('value')
            .eq('key', 'trip_email_domain')
            .single(),
      ]);

      return TripEmailAliasModel(
        itineraryId: itineraryId,
        localPart: results[0]['local_part'] as String,
        domain: results[1]['value'] as String,
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
