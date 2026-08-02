import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/ai_generation_request.dart';
import '../entities/ai_generation_result.dart';
import '../repositories/ai_generation_repository.dart';

class GenerateItineraryUseCase {
  const GenerateItineraryUseCase(this._repository);

  final AiGenerationRepository _repository;

  Future<Either<Failure, AiGenerationResult>> call(
    AiGenerationRequest request,
  ) =>
      _repository.generateItinerary(request);
}
