import '../../domain/entities/rating.dart';

class RatingModel extends Rating {
  const RatingModel({
    required super.id,
    required super.itineraryId,
    required super.targetName,
    required super.stars,
    required super.userId,
    required super.userName,
    required super.createdAt,
    super.itemId,
    super.comment,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) => RatingModel(
        id: json['id'] as String,
        itineraryId: json['itinerary_id'] as String,
        targetName: json['target_name'] as String,
        stars: json['stars'] as int,
        userId: json['user_id'] as String,
        userName: json['user_name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        itemId: json['item_id'] as String?,
        comment: json['comment'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'itinerary_id': itineraryId,
        'target_name': targetName,
        'stars': stars,
        'user_id': userId,
        'user_name': userName,
        'created_at': createdAt.toIso8601String(),
        if (itemId != null) 'item_id': itemId,
        if (comment != null) 'comment': comment,
      };
}
