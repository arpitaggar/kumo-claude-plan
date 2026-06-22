import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/packing_item.dart';

abstract class PackingRepository {
  Stream<Either<Failure, List<PackingItem>>> watchItems(String itineraryId);
  Future<Either<Failure, PackingItem>> addItem(PackingItem item);
  Future<Either<Failure, void>> toggleItem(String id, {required bool isChecked});
  Future<Either<Failure, void>> deleteItem(String id);
}
