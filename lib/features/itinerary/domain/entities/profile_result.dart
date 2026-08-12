import 'package:equatable/equatable.dart';

/// A lookup result from the profile-search/invite flow — deliberately
/// narrower than `UserProfile` (the `profile` feature's own entity): only
/// the columns invite/privacy screens ever need, and never another user's
/// email unless the caller is looking themselves up.
class ProfileResult extends Equatable {
  const ProfileResult({
    required this.id,
    required this.displayName,
    required this.email,
    required this.isSearchable,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String email;
  final bool isSearchable;
  final String? avatarUrl;

  @override
  List<Object?> get props => [id, displayName, email, isSearchable, avatarUrl];
}
