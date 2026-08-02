import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/ai_generation_request.dart';
import '../entities/ai_generation_result.dart';

// ignore: one_member_abstracts
abstract class AiGenerationRepository {
  Future<Either<Failure, AiGenerationResult>> generateItinerary(
    AiGenerationRequest request,
  );
}
