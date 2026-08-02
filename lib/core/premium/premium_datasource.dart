import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../error/exception.dart';
import '../network/supabase_client.dart';
import 'premium_feature.dart';

abstract class PremiumFeatureDataSource {
  Future<List<PremiumFeature>> fetchAll();
}

class PremiumFeatureDataSourceImpl implements PremiumFeatureDataSource {
  const PremiumFeatureDataSourceImpl();

  static const _table = 'feature_flags';

  @override
  Future<List<PremiumFeature>> fetchAll() async {
    try {
      final rows = await KumoSupabaseClient.client.from(_table).select();
      return rows.map(PremiumFeature.fromJson).toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
