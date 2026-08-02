import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/trip_segment.dart';
import '../../domain/repositories/trip_segment_repository.dart';
import '../datasources/trip_segment_remote_datasource.dart';
import '../models/trip_segment_model.dart';

class TripSegmentRepositoryImpl implements TripSegmentRepository {
  const TripSegmentRepositoryImpl({required this.dataSource});

  final TripSegmentRemoteDataSource dataSource;

  @override
  Stream<Either<Failure, List<TripSegment>>> watchSegments(
    String itineraryId,
  ) =>
      dataSource
          .watchSegments(itineraryId)
          .map<Either<Failure, List<TripSegment>>>(Right.new)
          .handleError(
            (Object e) => Left(
              e is ServerException
                  ? ServerFailure(e.message)
                  : UnexpectedFailure(e.toString()),
            ),
          );

  @override
  Future<Either<Failure, TripSegment>> addSegment(TripSegment segment) async {
    try {
      final saved =
          await dataSource.addSegment(TripSegmentModel.fromEntity(segment));
      return Right(saved);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TripSegment>> updateSegment(
    TripSegment segment,
  ) async {
    try {
      final saved = await dataSource
          .updateSegment(TripSegmentModel.fromEntity(segment));
      return Right(saved);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSegment(String segmentId) async {
    try {
      await dataSource.deleteSegment(segmentId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> reorderSegments(
    String itineraryId,
    List<TripSegment> reordered,
  ) async {
    try {
      await dataSource.reorderSegments(
        reordered.map(TripSegmentModel.fromEntity).toList(),
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
