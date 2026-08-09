import 'dart:async';

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
  Stream<Either<Failure, List<PackingItem>>> watchItems(String itineraryId) =>
      dataSource
          .watchItems(itineraryId)
          .transform(
            // `Stream.handleError`'s callback return value is silently
            // discarded — it only suppresses the error, it can't inject a
            // replacement event. A `StreamTransformer` sink is the only way to
            // turn an upstream stream error into a `Left(...)` value.
            StreamTransformer.fromHandlers(
              handleData: (data, sink) => sink.add(Right(data)),
              handleError: (error, stackTrace, sink) =>
                  sink.add(Left(ServerFailure(error.toString()))),
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
  Future<Either<Failure, void>> toggleItem(
    String id, {
    required bool isChecked,
  }) async {
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
