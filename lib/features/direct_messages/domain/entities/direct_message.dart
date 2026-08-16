import 'package:equatable/equatable.dart';

import '../../../chat/domain/entities/message_attachment.dart';

class DirectMessage extends Equatable {
  const DirectMessage({
    required this.id,
    required this.dmConversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.readBy = const [],
    this.attachments = const [],
  });

  final String id;
  final String dmConversationId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;
  final List<String> readBy;
  final List<MessageAttachment> attachments;

  bool get hasAttachments => attachments.isNotEmpty;

  @override
  List<Object> get props => [
    id,
    dmConversationId,
    senderId,
    senderName,
    content,
    createdAt,
    readBy,
    attachments,
  ];
}
