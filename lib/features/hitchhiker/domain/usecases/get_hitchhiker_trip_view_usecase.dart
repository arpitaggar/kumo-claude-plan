import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/hitchhiker_trip_view.dart';
import '../repositories/hitchhiker_access_repository.dart';

class GetHitchhikerTripViewUseCase {
  const GetHitchhikerTripViewUseCase(this._repository);

  final HitchhikerAccessRepository _repository;

  Future<Either<Failure, HitchhikerTripView>> call(String token) =>
      _repository.getTripView(token);
}
