import '../../domain/entities/packing_item.dart';

class PackingItemModel extends PackingItem {
  const PackingItemModel({
    required super.id,
    required super.itineraryId,
    required super.title,
    required super.isChecked,
    required super.addedById,
    required super.addedByName,
    required super.createdAt,
    super.category,
  });

  factory PackingItemModel.fromJson(Map<String, dynamic> json) =>
      PackingItemModel(
        id: json['id'] as String,
        itineraryId: json['itinerary_id'] as String,
        title: json['title'] as String,
        isChecked: json['is_checked'] as bool? ?? false,
        addedById: json['added_by_id'] as String,
        addedByName: json['added_by_name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        category: json['category'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'itinerary_id': itineraryId,
        'title': title,
        'is_checked': isChecked,
        'added_by_id': addedById,
        'added_by_name': addedByName,
        'created_at': createdAt.toIso8601String(),
        if (category != null) 'category': category,
      };
}
