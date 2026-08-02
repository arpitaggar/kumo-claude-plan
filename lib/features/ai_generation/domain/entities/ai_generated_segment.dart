import 'package:equatable/equatable.dart';

import '../../../itinerary/domain/entities/transport_mode.dart';

/// A transport leg suggested by the AI generator — origin/destination are
/// plain city names, not yet geocoded to lat/lng. Only produced when the
/// user's destination describes multiple stops travelled in sequence (e.g.
/// "Munich, Bangkok, Chiang Mai, Pai"); empty for a single-destination trip.
class AiGeneratedSegment extends Equatable {
  const AiGeneratedSegment({
    required this.mode,
    required this.originName,
    required this.destinationName,
    this.departureTime,
    this.arrivalTime,
  });

  final TransportMode mode;
  final String originName;
  final String destinationName;
  final DateTime? departureTime;
  final DateTime? arrivalTime;

  @override
  List<Object?> get props =>
      [mode, originName, destinationName, departureTime, arrivalTime];
}
