import '../../domain/entities/organization.dart';

class OrganizationModel extends Organization {
  const OrganizationModel({
    required super.id,
    required super.name,
    required super.slug,
    required super.ownerId,
    required super.createdAt,
    required super.updatedAt,
    super.defaultApprovalThreshold,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) =>
      OrganizationModel(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        ownerId: json['owner_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
        defaultApprovalThreshold: (json['default_approval_threshold'] as num?)
            ?.toDouble(),
      );

  Map<String, dynamic> toJson() => {'name': name, 'slug': slug};
}
