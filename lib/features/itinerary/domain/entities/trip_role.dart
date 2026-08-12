/// The three participant tiers on a Kumo trip.
///
/// This is a *classification* layered on top of the existing storage model,
/// not a new column: [captain] is `itineraries.owner_id`, [crew] is an entry
/// in `itineraries.members` (see [GroupMember]/`GroupMemberRole`), and
/// [hitchhiker] is a row in `trip_hitchhikers`
/// (`lib/features/hitchhiker/domain/entities/hitchhiker.dart`).
///
/// *** [hitchhiker] is not a themed label — see docs/ARCHITECTURE.md. ***
/// It carries real regulatory weight: no independent data profile is ever
/// created for this role (no `user_id`, no `auth.users` row, no cross-trip
/// identity), by design, specifically to stay outside COPPA/UK-AADC/GDPR
/// minor-data-controller obligations. Don't "simplify" Hitchhiker into a
/// lightweight Crew account — see `docs/supabase_migrations/
/// stage44_age_gate.sql` and `stage45_hitchhikers.sql` for why.
enum TripRole {
  /// Trip owner. Full account (18+). Admin rights: invite/remove Crew and
  /// Hitchhikers, manage expenses, publish the trip.
  captain,

  /// A full-account (18+) collaborator invited onto someone else's trip —
  /// today's existing member model (`GroupMember`/`GroupMemberRole`). Has
  /// their own `user_id`, login, and cross-trip identity.
  crew,

  /// Non-account collaborator, scoped to exactly one trip. See the
  /// class-level warning above before touching anything related to this.
  hitchhiker,
}

/// True iff [role] is the regulatorily-significant non-account tier. Prefer
/// this over `role == TripRole.hitchhiker` at call sites that gate a
/// feature specifically *because* of the no-account-data guarantee (e.g.
/// deciding whether to include a participant in an AI prompt, a marketing
/// send, or the publishing/discovery layer) — it reads as an intentional
/// policy check rather than an incidental enum comparison.
bool isHitchhiker(TripRole role) => role == TripRole.hitchhiker;

/// Classifies a participant on a trip given the trip's [ownerId] and
/// [memberUserIds] (from its `members` array) plus the identity in
/// question. Exactly one of [userId] / [isHitchhikerContext] should be
/// meaningful for a given caller — pass [isHitchhikerContext]: true from
/// code that already knows it's operating via a Hitchhiker access token
/// (there's no `userId` to check in that case at all).
TripRole resolveTripRole({
  required String ownerId,
  required Iterable<String> memberUserIds,
  String? userId,
  bool isHitchhikerContext = false,
}) {
  if (isHitchhikerContext) {
    return TripRole.hitchhiker;
  }
  if (userId != null && userId == ownerId) {
    return TripRole.captain;
  }
  if (userId != null && memberUserIds.contains(userId)) {
    return TripRole.crew;
  }
  // Not the owner, not a listed member, and not a Hitchhiker context — this
  // shouldn't normally be reachable (RLS wouldn't have returned trip data to
  // this identity in the first place), but callers that build a label from
  // partial/cached data should treat it as the safest default: never assume
  // elevated (Captain) rights for an unrecognized identity.
  return TripRole.crew;
}
