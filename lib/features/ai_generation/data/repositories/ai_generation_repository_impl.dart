import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../domain/entities/ai_generation_request.dart';
import '../../domain/repositories/ai_generation_repository.dart';
import '../datasources/ai_generation_datasource.dart';

class AiGenerationRepositoryImpl implements AiGenerationRepository {
  const AiGenerationRepositoryImpl({required this.dataSource});

  final AiGenerationDataSource dataSource;

  @override
  Future<Either<Failure, List<ItineraryItem>>> generateItinerary(
    AiGenerationRequest request,
  ) async {
    try {
      final items = await dataSource.generateItinerary(request);
      return Right(items);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
