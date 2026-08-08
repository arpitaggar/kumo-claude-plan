import 'package:equatable/equatable.dart';

/// A trip's masked, forward-only email address — no inbox exists for it.
/// Anything sent to [address] is fanned out to every trip member by the
/// `inbound-trip-email` Edge Function; see stage27's migration comment for
/// the full mechanism and required (non-code) provider setup.
class TripEmailAlias extends Equatable {
  const TripEmailAlias({
    required this.itineraryId,
    required this.localPart,
    required this.domain,
  });

  final String itineraryId;
  final String localPart;
  final String domain;

  String get address => '$localPart@$domain';

  @override
  List<Object?> get props => [itineraryId, localPart, domain];
}
