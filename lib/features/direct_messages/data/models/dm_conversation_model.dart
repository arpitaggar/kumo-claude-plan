import '../../domain/entities/dm_conversation.dart';

class DmConversationProfileInfo {
  const DmConversationProfileInfo({required this.displayName, this.avatarUrl});

  final String displayName;
  final String? avatarUrl;
}

class DmConversationModel extends DmConversation {
  const DmConversationModel({
    required super.id,
    required super.otherUserId,
    required super.otherUserName,
    super.otherUserAvatarUrl,
    super.lastMessageAt,
    super.lastMessagePreview,
    super.lastMessageSenderId,
  });

  /// `.stream()` can't embed a join to `profiles`, so [profilesById] is
  /// fetched in a separate batched query and merged in here — same
  /// two-query pattern `ChatRemoteDataSourceImpl._withAttachments` uses for
  /// message attachments.
  factory DmConversationModel.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
    required Map<String, DmConversationProfileInfo> profilesById,
  }) {
    final userA = json['user_a'] as String;
    final userB = json['user_b'] as String;
    final otherUserId = userA == currentUserId ? userB : userA;
    final profile = profilesById[otherUserId];
    final lastMessageAtRaw = json['last_message_at'] as String?;

    return DmConversationModel(
      id: json['id'] as String,
      otherUserId: otherUserId,
      otherUserName: profile?.displayName ?? '',
      otherUserAvatarUrl: profile?.avatarUrl,
      lastMessageAt: lastMessageAtRaw == null
          ? null
          : DateTime.parse(lastMessageAtRaw).toUtc(),
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
    );
  }
}
