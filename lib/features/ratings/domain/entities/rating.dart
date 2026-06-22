import 'package:equatable/equatable.dart';

class Rating extends Equatable {
  const Rating({
    required this.id,
    required this.itineraryId,
    required this.targetName,
    required this.stars,
    required this.userId,
    required this.userName,
    required this.createdAt,
    this.itemId,
    this.comment,
  });

  final String id;
  final String itineraryId;
  final String? itemId;
  final String targetName;
  final int stars;
  final String? comment;
  final String userId;
  final String userName;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        itineraryId,
        itemId,
        targetName,
        stars,
        comment,
        userId,
        userName,
        createdAt,
      ];
}
