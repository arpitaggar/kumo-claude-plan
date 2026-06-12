import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/user.dart';

/// Data model that extends [User] with JSON serialization.
///
/// Maps between Supabase auth responses and the domain [User] entity.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.createdAt,
    super.displayName,
    super.avatarUrl,
    super.lastSignInAt,
    super.emailVerified,
    super.phoneNumber,
    super.mfaEnabled,
  });

  factory UserModel.fromSupabaseUser(sb.User user) => UserModel(
    id: user.id,
    email: user.email ?? '',
    createdAt: DateTime.parse(user.createdAt),
    displayName: user.userMetadata?['display_name'] as String?,
    avatarUrl: user.userMetadata?['avatar_url'] as String?,
    lastSignInAt: user.lastSignInAt != null
        ? DateTime.parse(user.lastSignInAt!)
        : null,
    emailVerified: user.emailConfirmedAt != null,
    phoneNumber: user.phone,
  );

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    email: json['email'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    lastSignInAt: json['last_sign_in_at'] != null
        ? DateTime.parse(json['last_sign_in_at'] as String)
        : null,
    emailVerified: json['email_verified'] as bool? ?? false,
    phoneNumber: json['phone_number'] as String?,
    mfaEnabled: json['mfa_enabled'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'created_at': createdAt.toIso8601String(),
    'last_sign_in_at': lastSignInAt?.toIso8601String(),
    'email_verified': emailVerified,
    'phone_number': phoneNumber,
    'mfa_enabled': mfaEnabled,
  };
}
