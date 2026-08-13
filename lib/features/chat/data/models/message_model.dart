import '../../domain/entities/message.dart';
import 'message_attachment_model.dart';

class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.itineraryId,
    required super.senderId,
    required super.senderName,
    required super.content,
    required super.createdAt,
    super.readBy,
    super.attachments,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
    id: json['id'] as String,
    itineraryId: json['itinerary_id'] as String,
    // sender_id is null for a Hitchhiker-authored message (see
    // stage45_hitchhikers.sql's messages_sender_xor_hitchhiker constraint —
    // exactly one of sender_id/hitchhiker_id is set). Falling back to the
    // row's own hitchhiker_id keeps senderId non-null (required elsewhere,
    // e.g. the "same sender" grouping check in chat_page.dart) while still
    // distinguishing between different Hitchhikers, unlike falling back to
    // a constant empty string. It can never collide with a real user's
    // senderId (disjoint uuid spaces), so `isMe` comparisons stay correct.
    senderId:
        (json['sender_id'] as String?) ??
        (json['hitchhiker_id'] as String?) ??
        '',
    senderName: (json['sender_name'] as String?) ?? '',
    content: (json['content'] as String?) ?? '',
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    readBy: (json['read_by'] as List?)?.cast<String>() ?? const [],
    attachments:
        (json['message_attachments'] as List?)
            ?.map(
              (a) => MessageAttachmentModel.fromJson(a as Map<String, dynamic>),
            )
            .toList() ??
        const [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'itinerary_id': itineraryId,
    'sender_id': senderId,
    'sender_name': senderName,
    'content': content,
    'created_at': createdAt.toIso8601String(),
    'read_by': readBy,
  };
}
