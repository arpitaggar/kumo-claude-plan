import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/itinerary_post.dart';
import '../repositories/social_repository.dart';

class FetchExplorePostsUseCase {
  const FetchExplorePostsUseCase(this._repository);

  final SocialRepository _repository;

  Future<Either<Failure, List<ItineraryPost>>> call({String? query}) =>
      _repository.fetchExplore(query: query);
}
