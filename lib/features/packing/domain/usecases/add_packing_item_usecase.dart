import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../entities/packing_item.dart';
import '../repositories/packing_repository.dart';

class AddPackingItemUseCase {
  const AddPackingItemUseCase(this._repository);

  final PackingRepository _repository;

  Future<Either<Failure, PackingItem>> call({
    required String itineraryId,
    required String title,
    required String addedById,
    required String addedByName,
    String? category,
  }) => _repository.addItem(
        PackingItem(
          id: const Uuid().v4(),
          itineraryId: itineraryId,
          title: title.trim(),
          isChecked: false,
          addedById: addedById,
          addedByName: addedByName,
          createdAt: DateTime.now().toUtc(),
          category: category,
        ),
      );
}
