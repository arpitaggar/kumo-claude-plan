import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/packing_repository.dart';

class TogglePackingItemUseCase {
  const TogglePackingItemUseCase(this._repository);

  final PackingRepository _repository;

  Future<Either<Failure, void>> call(String id, {required bool isChecked}) =>
      _repository.toggleItem(id, isChecked: isChecked);
}
