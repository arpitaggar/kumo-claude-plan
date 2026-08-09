import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/trip_cost_field_value_remote_datasource.dart';
import '../../data/repositories/trip_cost_field_value_repository_impl.dart';
import '../../domain/entities/trip_cost_field_value.dart';
import '../../domain/usecases/fetch_trip_cost_field_values_usecase.dart';
import '../../domain/usecases/set_trip_cost_field_values_usecase.dart';

final tripCostFieldValueDataSourceProvider =
    Provider<TripCostFieldValueRemoteDataSource>(
      (_) => const TripCostFieldValueRemoteDataSourceImpl(),
    );

final tripCostFieldValueRepositoryProvider =
    Provider<TripCostFieldValueRepositoryImpl>(
      (ref) => TripCostFieldValueRepositoryImpl(
        dataSource: ref.watch(tripCostFieldValueDataSourceProvider),
      ),
    );

final fetchTripCostFieldValuesUseCaseProvider =
    Provider<FetchTripCostFieldValuesUseCase>(
      (ref) => FetchTripCostFieldValuesUseCase(
        ref.watch(tripCostFieldValueRepositoryProvider),
      ),
    );

final setTripCostFieldValuesUseCaseProvider =
    Provider<SetTripCostFieldValuesUseCase>(
      (ref) => SetTripCostFieldValuesUseCase(
        ref.watch(tripCostFieldValueRepositoryProvider),
      ),
    );

/// A trip's assigned cost-field values. No realtime — set once (or edited
/// rarely) per trip, refreshed via `ref.invalidate` after a save, same
/// reasoning as `tripEmailAliasProvider`.
final tripCostFieldValuesProvider =
    FutureProvider.family<List<TripCostFieldValue>, String>((
      ref,
      itineraryId,
    ) async {
      final result = await ref
          .watch(fetchTripCostFieldValuesUseCaseProvider)
          .call(itineraryId);
      return result.fold((f) => throw Exception(f.message), (values) => values);
    });
