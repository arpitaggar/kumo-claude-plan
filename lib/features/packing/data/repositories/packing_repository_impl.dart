import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/packing_item.dart';
import '../../domain/repositories/packing_repository.dart';
import '../datasources/packing_remote_datasource.dart';
import '../models/packing_item_model.dart';

class PackingRepositoryImpl implements PackingRepository {
  const PackingRepositoryImpl({required this.dataSource});

  final PackingRemoteDataSource dataSource;

  @override
  Stream<Either<Failure, List<PackingItem>>> watchItems(
          String itineraryId) =>
      dataSource
          .watchItems(itineraryId)
          .map<Either<Failure, List<PackingItem>>>(Right.new)
          .handleError(
            (Object e) => Left<Failure, List<PackingItem>>(
              ServerFailure(e.toString()),
            ),
          );

  @override
  Future<Either<Failure, PackingItem>> addItem(PackingItem item) async {
    try {
      final model = PackingItemModel(
        id: item.id,
        itineraryId: item.itineraryId,
        title: item.title,
        isChecked: item.isChecked,
        addedById: item.addedById,
        addedByName: item.addedByName,
        createdAt: item.createdAt,
        category: item.category,
      );
      final result = await dataSource.addItem(model);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleItem(String id,
      {required bool isChecked}) async {
    try {
      await dataSource.toggleItem(id, isChecked: isChecked);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteItem(String id) async {
    try {
      await dataSource.deleteItem(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
