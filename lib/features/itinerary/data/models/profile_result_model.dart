import '../../domain/entities/profile_result.dart';

class ProfileResultModel extends ProfileResult {
  const ProfileResultModel({
    required super.id,
    required super.displayName,
    required super.email,
    required super.isSearchable,
    super.avatarUrl,
  });

  factory ProfileResultModel.fromRow(Map<String, dynamic> row) =>
      ProfileResultModel(
        id: row['id'] as String,
        displayName: (row['display_name'] as String?) ?? '',
        email: row['email'] as String,
        isSearchable: (row['is_searchable'] as bool?) ?? true,
        avatarUrl: row['avatar_url'] as String?,
      );
}
