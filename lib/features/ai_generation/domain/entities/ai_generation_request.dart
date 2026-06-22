import 'package:equatable/equatable.dart';

class AiGenerationRequest extends Equatable {
  const AiGenerationRequest({
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.travelStyle,
    this.interests,
    this.currencyCode = 'USD',
  });

  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final TravelStyle travelStyle;
  final String? interests;
  final String currencyCode;

  int get tripDays => endDate.difference(startDate).inDays + 1;

  @override
  List<Object?> get props =>
      [destination, startDate, endDate, travelStyle, interests, currencyCode];
}

enum TravelStyle {
  adventure('Adventure & Outdoors'),
  relaxation('Relaxation & Wellness'),
  culture('Culture & History'),
  food('Food & Nightlife'),
  family('Family Friendly');

  const TravelStyle(this.label);
  final String label;
}
