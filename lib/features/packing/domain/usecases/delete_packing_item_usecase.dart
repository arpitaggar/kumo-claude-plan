import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/packing_repository.dart';

class DeletePackingItemUseCase {
  const DeletePackingItemUseCase(this._repository);

  final PackingRepository _repository;

  Future<Either<Failure, void>> call(String id) =>
      _repository.deleteItem(id);
}
