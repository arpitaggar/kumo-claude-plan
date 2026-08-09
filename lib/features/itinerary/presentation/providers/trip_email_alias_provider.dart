import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/trip_email_alias_remote_datasource.dart';
import '../../data/repositories/trip_email_alias_repository_impl.dart';
import '../../domain/entities/trip_email_alias.dart';

final tripEmailAliasDataSourceProvider =
    Provider<TripEmailAliasRemoteDataSource>(
      (_) => const TripEmailAliasRemoteDataSourceImpl(),
    );

final tripEmailAliasRepositoryProvider = Provider<TripEmailAliasRepositoryImpl>(
  (ref) => TripEmailAliasRepositoryImpl(
    dataSource: ref.watch(tripEmailAliasDataSourceProvider),
  ),
);

/// The alias never changes after creation (see stage27's migration), so a
/// one-shot `FutureProvider` is enough — no realtime stream needed, unlike
/// `tripSegmentsStreamProvider`.
final tripEmailAliasProvider = FutureProvider.family<TripEmailAlias, String>((
  ref,
  itineraryId,
) async {
  final result = await ref
      .watch(tripEmailAliasRepositoryProvider)
      .getAlias(itineraryId);
  return result.fold((f) => throw Exception(f.message), (alias) => alias);
});
