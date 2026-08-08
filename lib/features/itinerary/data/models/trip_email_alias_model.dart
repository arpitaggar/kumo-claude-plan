import '../../domain/entities/trip_email_alias.dart';

class TripEmailAliasModel extends TripEmailAlias {
  const TripEmailAliasModel({
    required super.itineraryId,
    required super.localPart,
    required super.domain,
  });
}
