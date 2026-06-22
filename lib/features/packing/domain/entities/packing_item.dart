import 'package:equatable/equatable.dart';

class PackingItem extends Equatable {
  const PackingItem({
    required this.id,
    required this.itineraryId,
    required this.title,
    required this.isChecked,
    required this.addedById,
    required this.addedByName,
    required this.createdAt,
    this.category,
  });

  final String id;
  final String itineraryId;
  final String title;
  final bool isChecked;
  final String addedById;
  final String addedByName;
  final DateTime createdAt;
  final String? category;

  @override
  List<Object?> get props => [
        id,
        itineraryId,
        title,
        isChecked,
        addedById,
        addedByName,
        createdAt,
        category,
      ];
}
