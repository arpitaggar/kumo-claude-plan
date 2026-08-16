import 'package:equatable/equatable.dart';

/// One DM thread, from the current user's point of view — `otherUserId`/
/// `otherUserName`/`otherUserAvatarUrl` are always the *other* participant,
/// resolved client-side against `profiles`, never the caller themselves.
class DmConversation extends Equatable {
  const DmConversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
  });

  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarUrl;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSenderId;

  @override
  List<Object?> get props => [
    id,
    otherUserId,
    otherUserName,
    otherUserAvatarUrl,
    lastMessageAt,
    lastMessagePreview,
    lastMessageSenderId,
  ];
}
