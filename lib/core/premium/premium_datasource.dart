import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../error/exception.dart';
import '../network/supabase_client.dart';
import 'premium_feature.dart';

abstract class PremiumFeatureDataSource {
  Future<List<PremiumFeature>> fetchAll();

  /// Whether any org department the signed-in user belongs to has an
  /// override granting [featureKey] (`stage39_department_overrides.sql`) —
  /// checked via RPC rather than a direct table read, since a regular
  /// member has no RLS-select access to `org_feature_overrides` (only org
  /// admins do, for managing it), just this narrow yes/no slice about
  /// their own department membership.
  Future<bool> hasDepartmentOverride(String featureKey);
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

  @override
  Future<bool> hasDepartmentOverride(String featureKey) async {
    try {
      final result = await KumoSupabaseClient.client.rpc(
        'has_department_feature_override',
        params: {'p_feature_key': featureKey},
      );
      return result as bool? ?? false;
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
