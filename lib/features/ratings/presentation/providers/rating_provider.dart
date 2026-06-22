import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/rating_remote_datasource.dart';
import '../../data/repositories/rating_repository_impl.dart';
import '../../domain/entities/rating.dart';
import '../../domain/usecases/add_rating_usecase.dart';
import '../../domain/usecases/delete_rating_usecase.dart';

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

final ratingDataSourceProvider = Provider<RatingRemoteDataSource>(
  (_) => const RatingRemoteDataSourceImpl(),
);

final ratingRepositoryProvider = Provider<RatingRepositoryImpl>(
  (ref) => RatingRepositoryImpl(
    dataSource: ref.watch(ratingDataSourceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Use-case providers
// ---------------------------------------------------------------------------

final addRatingUseCaseProvider = Provider<AddRatingUseCase>(
  (ref) => AddRatingUseCase(ref.watch(ratingRepositoryProvider)),
);

final deleteRatingUseCaseProvider = Provider<DeleteRatingUseCase>(
  (ref) => DeleteRatingUseCase(ref.watch(ratingRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Stream provider — live rating list per itinerary
// ---------------------------------------------------------------------------

final ratingStreamProvider =
    StreamProvider.family<List<Rating>, String>((ref, itineraryId) => ref
        .watch(ratingRepositoryProvider)
        .watchRatings(itineraryId)
        .map((either) => either.fold(
              (f) => throw Exception(f.message),
              (list) => list,
            )));
