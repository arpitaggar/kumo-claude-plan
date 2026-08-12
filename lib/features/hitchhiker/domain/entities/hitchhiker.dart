import 'package:equatable/equatable.dart';

/// A non-account collaborator on one specific trip — the "Hitchhiker" role.
///
/// *** Not a themed label — see docs/ARCHITECTURE.md. *** A Hitchhiker
/// deliberately has no [id] in `auth.users`/`public.profiles`, no login, no
/// DOB, and no identity beyond [displayName] and this one trip. This is what
/// keeps Kumo outside COPPA/UK-AADC/GDPR minor-data-controller obligations —
/// don't "simplify" this into a lightweight Crew account. See
/// `docs/supabase_migrations/stage45_hitchhikers.sql`.
///
/// This is the Captain-facing view (their own trip's roster) — [accessToken]
/// is only ever populated right after [displayName] is created via
/// `create_hitchhiker`, so the Captain can share the join link once; it is
/// intentionally re-fetchable later too (see stage45's RLS: the Captain
/// already has direct SELECT on this row).
class Hitchhiker extends Equatable {
  const Hitchhiker({
    required this.id,
    required this.itineraryId,
    required this.displayName,
    required this.accessToken,
    required this.createdAt,
    this.revokedAt,
  });

  final String id;
  final String itineraryId;
  final String displayName;
  final String accessToken;
  final DateTime createdAt;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;

  @override
  List<Object?> get props => [
    id,
    itineraryId,
    displayName,
    accessToken,
    createdAt,
    revokedAt,
  ];
}
