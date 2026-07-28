import 'package:equatable/equatable.dart';

/// One row of "who has seen this message" detail, shown on long-press.
class MessageReadReceipt extends Equatable {
  const MessageReadReceipt({
    required this.userId,
    required this.displayName,
    required this.readAt,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final DateTime readAt;

  @override
  List<Object?> get props => [userId, displayName, avatarUrl, readAt];
}
