import 'package:equatable/equatable.dart';

import '../../../itinerary/domain/entities/travel_itinerary.dart';
import 'ai_generated_segment.dart';

class AiGenerationResult extends Equatable {
  const AiGenerationResult({required this.items, this.segments = const []});

  final List<ItineraryItem> items;
  final List<AiGeneratedSegment> segments;

  @override
  List<Object?> get props => [items, segments];
}
