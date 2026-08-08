import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/trip_email_alias.dart';

abstract class TripEmailAliasRepository {
  /// The trip's masked email alias — generated server-side (see stage27's
  /// migration) the moment the itinerary is created, so this is always
  /// expected to find a row rather than needing an explicit "create" call.
  Future<Either<Failure, TripEmailAlias>> getAlias(String itineraryId);
}
