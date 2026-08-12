import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/hitchhiker_trip_view.dart';

/// Token-authenticated access for the Hitchhiker themselves — no Supabase
/// Auth session involved at all (see `docs/ARCHITECTURE.md`). Every method
/// takes `token` explicitly and calls a SECURITY DEFINER RPC that validates
/// it server-side; there is nothing else identifying the caller.
abstract class HitchhikerAccessRepository {
  Future<Either<Failure, HitchhikerTripView>> getTripView(String token);

  Future<Either<Failure, void>> sendMessage({
    required String token,
    required String content,
  });

  Future<Either<Failure, void>> suggestItem({
    required String token,
    required String title,
    String? description,
  });
}
