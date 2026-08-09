import 'package:equatable/equatable.dart';

/// Extended profile row from the `profiles` table.
///
/// Distinct from the auth User entity (which mirrors Supabase Auth metadata).
/// Holds application-layer identity and preference fields.
/// The [id] UUID is the *only* stable identifier referenced by foreign keys —
/// never use [username] as an FK target since it is mutable.
class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.isSearchable,
    required this.profileVisibility,
    required this.contactVisibility,
    required this.unitsPreference,
    required this.travelPreferenceTags,
    required this.updatedAt,
    // Privacy by default (SEC-017) — matches the profiles table's own
    // column default (see stage23_security_hardening.sql). New users start
    // with chat content hidden from lock-screen/notification-shade previews
    // and must opt in, rather than opting out after the fact.
    this.pushMessagePreviewEnabled = false,
    this.username,
    this.avatarUrl,
    this.bio,
    this.city,
    this.country,
    this.timezone,
    this.preferredCurrency,
    this.preferredLanguage,
    this.usernameLastChangedAt,
  });

  final String id;
  final String email;
  final String displayName;

  /// Unique handle used in mentions. Nullable — existing users may not have set one.
  final String? username;
  final String? avatarUrl;
  final String? bio;

  // Localisation
  final String? city;
  final String? country; // ISO 3166-1 alpha-2
  final String? timezone;
  final String? preferredCurrency; // ISO 4217
  final String? preferredLanguage; // ISO 639-1

  /// 'metric' or 'imperial'
  final String unitsPreference;

  /// Tags from the predefined travel-interest list.
  final List<String> travelPreferenceTags;

  // Privacy
  final bool isSearchable;

  /// 'public' or 'private' — controls appearance in the discovery feed.
  final String profileVisibility;

  /// 'collaborators_only' or 'hidden' — controls email/phone exposure.
  final String contactVisibility;

  final DateTime? usernameLastChangedAt;
  final DateTime updatedAt;

  /// Whether push-notification banners for chat messages show the message
  /// text, or a generic "New message" placeholder.
  final bool pushMessagePreviewEnabled;

  /// True when the 7-day username-change cooldown has elapsed (or never set).
  bool get canChangeUsername {
    final last = usernameLastChangedAt;
    return last == null ||
        DateTime.now().difference(last) >= const Duration(days: 7);
  }

  /// The earliest date/time the username can next be changed.
  DateTime? get nextUsernameChangeAt =>
      usernameLastChangedAt?.add(const Duration(days: 7));

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? username,
    String? avatarUrl,
    String? bio,
    String? city,
    String? country,
    String? timezone,
    String? preferredCurrency,
    String? preferredLanguage,
    String? unitsPreference,
    List<String>? travelPreferenceTags,
    bool? isSearchable,
    String? profileVisibility,
    String? contactVisibility,
    DateTime? usernameLastChangedAt,
    DateTime? updatedAt,
    bool? pushMessagePreviewEnabled,
  }) => UserProfile(
    id: id ?? this.id,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    username: username ?? this.username,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    bio: bio ?? this.bio,
    city: city ?? this.city,
    country: country ?? this.country,
    timezone: timezone ?? this.timezone,
    preferredCurrency: preferredCurrency ?? this.preferredCurrency,
    preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    unitsPreference: unitsPreference ?? this.unitsPreference,
    travelPreferenceTags: travelPreferenceTags ?? this.travelPreferenceTags,
    isSearchable: isSearchable ?? this.isSearchable,
    profileVisibility: profileVisibility ?? this.profileVisibility,
    contactVisibility: contactVisibility ?? this.contactVisibility,
    usernameLastChangedAt: usernameLastChangedAt ?? this.usernameLastChangedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    pushMessagePreviewEnabled:
        pushMessagePreviewEnabled ?? this.pushMessagePreviewEnabled,
  );

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    username,
    avatarUrl,
    bio,
    city,
    country,
    timezone,
    preferredCurrency,
    preferredLanguage,
    unitsPreference,
    travelPreferenceTags,
    isSearchable,
    profileVisibility,
    contactVisibility,
    usernameLastChangedAt,
    updatedAt,
    pushMessagePreviewEnabled,
  ];
}
