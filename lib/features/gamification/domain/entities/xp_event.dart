import 'package:equatable/equatable.dart';

/// A single XP award, as recorded by a Postgres trigger on the source event
/// (a trip being created, a post getting liked, ...) — see
/// `docs/supabase_migrations/stage40_gamification.sql`. Append-only: a
/// user's current total is `sum(amount)` over their own events, not a
/// mutable counter.
class XpEvent extends Equatable {
  const XpEvent({
    required this.id,
    required this.userId,
    required this.amount,
    required this.reason,
    required this.sourceType,
    required this.sourceId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final int amount;

  /// Human-readable label shown in the "recent activity" list, e.g.
  /// "Completed a trip".
  final String reason;

  /// One of the `xp_events.source_type` check-constraint values — see
  /// [XpMetric] in `xp_summary.dart` for how these roll up into counts.
  final String sourceType;

  /// The id (or composite pair) of whatever triggered this award. Not used
  /// by the Flutter layer directly — exists purely as the anti-cheat dedup
  /// key on the database side.
  final String sourceId;

  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    userId,
    amount,
    reason,
    sourceType,
    sourceId,
    createdAt,
  ];
}
