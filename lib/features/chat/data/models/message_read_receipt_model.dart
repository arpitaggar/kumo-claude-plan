import '../../domain/entities/message_read_receipt.dart';

class MessageReadReceiptModel extends MessageReadReceipt {
  const MessageReadReceiptModel({
    required super.userId,
    required super.displayName,
    required super.readAt,
    super.avatarUrl,
  });

  factory MessageReadReceiptModel.fromJson(Map<String, dynamic> json) =>
      MessageReadReceiptModel(
        userId: json['user_id'] as String,
        displayName: (json['display_name'] as String?) ?? '',
        avatarUrl: json['avatar_url'] as String?,
        readAt: DateTime.parse(json['read_at'] as String).toUtc(),
      );
}
