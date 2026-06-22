import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../entities/ai_generation_request.dart';
import '../repositories/ai_generation_repository.dart';

class GenerateItineraryUseCase {
  const GenerateItineraryUseCase(this._repository);

  final AiGenerationRepository _repository;

  Future<Either<Failure, List<ItineraryItem>>> call(
    AiGenerationRequest request,
  ) =>
      _repository.generateItinerary(request);
}
