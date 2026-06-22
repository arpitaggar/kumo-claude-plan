import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/packing_remote_datasource.dart';
import '../../data/repositories/packing_repository_impl.dart';
import '../../domain/entities/packing_item.dart';
import '../../domain/usecases/add_packing_item_usecase.dart';
import '../../domain/usecases/delete_packing_item_usecase.dart';
import '../../domain/usecases/toggle_packing_item_usecase.dart';

final packingDataSourceProvider = Provider<PackingRemoteDataSource>(
  (_) => const PackingRemoteDataSourceImpl(),
);

final packingRepositoryProvider = Provider<PackingRepositoryImpl>(
  (ref) => PackingRepositoryImpl(
    dataSource: ref.watch(packingDataSourceProvider),
  ),
);

final addPackingItemUseCaseProvider = Provider<AddPackingItemUseCase>(
  (ref) => AddPackingItemUseCase(ref.watch(packingRepositoryProvider)),
);

final togglePackingItemUseCaseProvider = Provider<TogglePackingItemUseCase>(
  (ref) => TogglePackingItemUseCase(ref.watch(packingRepositoryProvider)),
);

final deletePackingItemUseCaseProvider = Provider<DeletePackingItemUseCase>(
  (ref) => DeletePackingItemUseCase(ref.watch(packingRepositoryProvider)),
);

final packingStreamProvider =
    StreamProvider.family<List<PackingItem>, String>((ref, itineraryId) => ref
        .watch(packingRepositoryProvider)
        .watchItems(itineraryId)
        .map((either) => either.fold(
              (f) => throw Exception(f.message),
              (list) => list,
            )));
