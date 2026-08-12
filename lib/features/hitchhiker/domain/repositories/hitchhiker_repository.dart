import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/hitchhiker.dart';

/// Captain-side management of Hitchhikers on their own trip. Every method
/// here requires a real signed-in session (Captain) — see
/// `hitchhiker_access_repository.dart` for the token-side (no session)
/// counterpart used by the Hitchhiker themselves.
abstract class HitchhikerRepository {
  /// Adds a Hitchhiker by name only. Server-side rejects unless the caller
  /// owns [itineraryId] (see `create_hitchhiker` in stage45).
  Future<Either<Failure, Hitchhiker>> createHitchhiker({
    required String itineraryId,
    required String displayName,
  });

  /// Immediately invalidates the Hitchhiker's access token/session — the
  /// Captain can do this at any time (product requirement).
  Future<Either<Failure, void>> revokeHitchhiker(String hitchhikerId);

  /// The trip's current Hitchhiker roster (including revoked ones, so the
  /// Captain's UI can show history) — normal RLS-scoped table read, not an
  /// RPC (the Captain already has direct SELECT via trip_hitchhikers_captain_all).
  Future<Either<Failure, List<Hitchhiker>>> listHitchhikers(String itineraryId);
}
