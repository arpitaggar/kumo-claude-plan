import '../../domain/entities/user_profile.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.id,
    required super.email,
    required super.displayName,
    required super.isSearchable,
    required super.profileVisibility,
    required super.contactVisibility,
    required super.unitsPreference,
    required super.travelPreferenceTags,
    required super.updatedAt,
    super.username,
    super.avatarUrl,
    super.bio,
    super.city,
    super.country,
    super.timezone,
    super.preferredCurrency,
    super.preferredLanguage,
    super.usernameLastChangedAt,
    super.pushMessagePreviewEnabled,
    super.ageVerifiedAt,
    super.enabledAccommodationSources,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['travel_preference_tags'];
    final tags = rawTags is List ? rawTags.cast<String>() : <String>[];

    return UserProfileModel(
      id: json['id'] as String,
      // Absent (not '' by accident) when fetched via getProfileById's
      // restricted column set for another user's profile — email is never
      // selected for anyone but the caller's own row (SEC-008).
      email: (json['email'] as String?) ?? '',
      displayName: (json['display_name'] as String?) ?? '',
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      timezone: json['timezone'] as String?,
      preferredCurrency: json['preferred_currency'] as String?,
      preferredLanguage: json['preferred_language'] as String?,
      unitsPreference: (json['units_preference'] as String?) ?? 'metric',
      travelPreferenceTags: tags,
      profileVisibility: (json['profile_visibility'] as String?) ?? 'public',
      contactVisibility:
          (json['contact_visibility'] as String?) ?? 'collaborators_only',
      isSearchable: (json['is_searchable'] as bool?) ?? true,
      usernameLastChangedAt: json['username_last_changed_at'] != null
          ? DateTime.parse(json['username_last_changed_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      pushMessagePreviewEnabled:
          (json['push_message_preview_enabled'] as bool?) ?? false,
      ageVerifiedAt: json['age_verified_at'] != null
          ? DateTime.parse(json['age_verified_at'] as String)
          : null,
      enabledAccommodationSources:
          (json['enabled_accommodation_sources'] as List?)?.cast<String>(),
    );
  }
}
