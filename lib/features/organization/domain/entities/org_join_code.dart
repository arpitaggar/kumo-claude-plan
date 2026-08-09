import 'package:equatable/equatable.dart';

import 'org_member.dart';

/// A self-serve join code (shown as text + QR in the app) that admits
/// whoever redeems it into [orgId], under [role] and — if the org has cost
/// fields configured — a specific department ([costFieldOptionId]). See
/// stage35's migration comment for the full security/concurrency design.
class OrgJoinCode extends Equatable {
  const OrgJoinCode({
    required this.id,
    required this.orgId,
    required this.role,
    required this.code,
    required this.usesCount,
    required this.createdBy,
    required this.createdAt,
    this.costFieldOptionId,
    this.expiresAt,
    this.maxUses,
    this.revokedAt,
  });

  final String id;
  final String orgId;

  /// The department this code grants, if the org uses cost-field-based
  /// department tracking. Null means "no department scoping."
  final String? costFieldOptionId;

  /// Never [OrgMemberRole.owner] — enforced server-side (stage35's
  /// `org_join_codes.role` CHECK constraint and `generate_org_join_code`'s
  /// own validation), not just a UI convention.
  final OrgMemberRole role;

  final String code;
  final DateTime? expiresAt;
  final int? maxUses;
  final int usesCount;
  final DateTime? revokedAt;
  final String createdBy;
  final DateTime createdAt;

  bool get isRevoked => revokedAt != null;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now().toUtc());

  bool get isExhausted => maxUses != null && usesCount >= maxUses!;

  /// Whether this code can still be redeemed — mirrors exactly the checks
  /// `redeem_org_join_code` performs server-side, so the admin list screen
  /// can show the same "active vs. not" status the server would enforce.
  bool get isActive => !isRevoked && !isExpired && !isExhausted;

  @override
  List<Object?> get props => [
    id,
    orgId,
    costFieldOptionId,
    role,
    code,
    expiresAt,
    maxUses,
    usesCount,
    revokedAt,
    createdBy,
    createdAt,
  ];
}
