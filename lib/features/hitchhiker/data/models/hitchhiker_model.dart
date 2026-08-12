import '../../domain/entities/hitchhiker.dart';

class HitchhikerModel extends Hitchhiker {
  const HitchhikerModel({
    required super.id,
    required super.itineraryId,
    required super.displayName,
    required super.accessToken,
    required super.createdAt,
    super.revokedAt,
  });

  factory HitchhikerModel.fromJson(Map<String, dynamic> json) =>
      HitchhikerModel(
        id: json['id'] as String,
        itineraryId: json['itinerary_id'] as String,
        displayName: json['display_name'] as String,
        accessToken: json['access_token'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        revokedAt: json['revoked_at'] != null
            ? DateTime.parse(json['revoked_at'] as String)
            : null,
      );
}
