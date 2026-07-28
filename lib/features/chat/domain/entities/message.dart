import 'package:equatable/equatable.dart';

import 'message_attachment.dart';

class Message extends Equatable {
  const Message({
    required this.id,
    required this.itineraryId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.readBy = const [],
    this.attachments = const [],
  });

  final String id;
  final String itineraryId;
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
        itineraryId,
        senderId,
        senderName,
        content,
        createdAt,
        readBy,
        attachments,
      ];
}
