import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/hitchhiker.dart';
import '../repositories/hitchhiker_repository.dart';

class ListHitchhikersUseCase {
  const ListHitchhikersUseCase(this._repository);

  final HitchhikerRepository _repository;

  Future<Either<Failure, List<Hitchhiker>>> call(String itineraryId) =>
      _repository.listHitchhikers(itineraryId);
}
