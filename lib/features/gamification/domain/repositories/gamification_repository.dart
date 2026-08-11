import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/xp_event.dart';

abstract class GamificationRepository {
  /// [userId]'s own XP events, newest first (bounded — see the datasource
  /// impl). Both the total/level and the "recent activity" list are derived
  /// from this same fetch client-side; there is no separate summary query.
  Future<Either<Failure, List<XpEvent>>> fetchXpEvents(String userId);
}
