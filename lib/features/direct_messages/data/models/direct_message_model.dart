import '../../../chat/data/models/message_attachment_model.dart';
import '../../domain/entities/direct_message.dart';

class DirectMessageModel extends DirectMessage {
  const DirectMessageModel({
    required super.id,
    required super.dmConversationId,
    required super.senderId,
    required super.senderName,
    required super.content,
    required super.createdAt,
    super.readBy,
    super.attachments,
  });

  factory DirectMessageModel.fromJson(Map<String, dynamic> json) =>
      DirectMessageModel(
        id: json['id'] as String,
        dmConversationId: json['dm_conversation_id'] as String,
        // sender_id is nullable at the column level (a Hitchhiker-authored
        // group-chat row uses hitchhiker_id instead — see
        // stage45_hitchhikers.sql), but a DM row's insert policy
        // (messages_dm_participant_insert) always requires sender_id =
        // auth.uid(), so this is defensive, not expected to ever fall back.
        senderId: (json['sender_id'] as String?) ?? '',
        senderName: (json['sender_name'] as String?) ?? '',
        content: (json['content'] as String?) ?? '',
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        readBy: (json['read_by'] as List?)?.cast<String>() ?? const [],
        attachments:
            (json['message_attachments'] as List?)
                ?.map(
                  (a) => MessageAttachmentModel.fromJson(
                    a as Map<String, dynamic>,
                  ),
                )
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'dm_conversation_id': dmConversationId,
    'sender_id': senderId,
    'sender_name': senderName,
    'content': content,
    'created_at': createdAt.toIso8601String(),
    'read_by': readBy,
  };
}
