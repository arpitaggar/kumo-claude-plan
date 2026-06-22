import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../entities/ai_generation_request.dart';

// ignore: one_member_abstracts
abstract class AiGenerationRepository {
  Future<Either<Failure, List<ItineraryItem>>> generateItinerary(
    AiGenerationRequest request,
  );
}
