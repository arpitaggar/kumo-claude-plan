import '../../domain/entities/message.dart';

class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.itineraryId,
    required super.senderId,
    required super.senderName,
    required super.content,
    required super.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'] as String,
        itineraryId: json['itinerary_id'] as String,
        senderId: json['sender_id'] as String,
        senderName: (json['sender_name'] as String?) ?? '',
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'itinerary_id': itineraryId,
        'sender_id': senderId,
        'sender_name': senderName,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };
}
