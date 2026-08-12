import 'package:equatable/equatable.dart';

import 'organization.dart' show Organization;

/// Membership of a user in an [Organization] — a separate axis from
/// `GroupMemberRole` (per-trip role): an org role governs org roster
/// management and expense-approval rights, never a specific trip's content.
/// See stage28's migration comment for why `manager`/`employee` from the
/// original architecture-doc sketch aren't part of this vocabulary.
class OrgMember extends Equatable {
  const OrgMember({
    required this.id,
    required this.orgId,
    required this.userId,
    required this.userName,
    required this.role,
    required this.joinedAt,
  });

  final String id;
  final String orgId;
  final String userId;
  final String userName;
  final OrgMemberRole role;
  final DateTime joinedAt;

  @override
  List<Object?> get props => [id, orgId, userId, userName, role, joinedAt];
}

enum OrgMemberRole {
  /// The organization's creator. Exactly one per org; never reassigned by
  /// the app today (see stage28's migration — ownership transfer is
  /// explicitly deferred).
  owner,

  /// Can manage the roster and review/approve submitted expenses.
  admin,

  /// Belongs to the org; can tag their own trips with it. Cannot manage the
  /// roster or review expenses.
  member,
}
