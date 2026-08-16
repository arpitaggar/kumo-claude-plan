import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/direct_messages/data/models/dm_conversation_model.dart';

void main() {
  Map<String, dynamic> baseJson({
    String userA = 'user-1',
    String userB = 'user-2',
    String? lastMessageAt,
  }) => {
    'id': 'conv-1',
    'user_a': userA,
    'user_b': userB,
    'last_message_at': lastMessageAt,
    'last_message_preview': 'Hey there',
    'last_message_sender_id': 'user-2',
  };

  group('DmConversationModel.fromJson', () {
    test('resolves otherUserId to user_b when the caller is user_a', () {
      final model = DmConversationModel.fromJson(
        baseJson(),
        currentUserId: 'user-1',
        profilesById: const {},
      );
      expect(model.otherUserId, 'user-2');
    });

    test('resolves otherUserId to user_a when the caller is user_b', () {
      final model = DmConversationModel.fromJson(
        baseJson(),
        currentUserId: 'user-2',
        profilesById: const {},
      );
      expect(model.otherUserId, 'user-1');
    });

    test('fills otherUserName/otherUserAvatarUrl from the profile map', () {
      final model = DmConversationModel.fromJson(
        baseJson(),
        currentUserId: 'user-1',
        profilesById: const {
          'user-2': DmConversationProfileInfo(
            displayName: 'Bob',
            avatarUrl: 'https://example.com/bob.png',
          ),
        },
      );
      expect(model.otherUserName, 'Bob');
      expect(model.otherUserAvatarUrl, 'https://example.com/bob.png');
    });

    test(
      'defaults otherUserName to empty string when no profile row was found',
      () {
        final model = DmConversationModel.fromJson(
          baseJson(),
          currentUserId: 'user-1',
          profilesById: const {},
        );
        expect(model.otherUserName, '');
        expect(model.otherUserAvatarUrl, isNull);
      },
    );

    test('lastMessageAt is null when the column is null', () {
      final model = DmConversationModel.fromJson(
        baseJson(),
        currentUserId: 'user-1',
        profilesById: const {},
      );
      expect(model.lastMessageAt, isNull);
    });

    test('parses a non-null lastMessageAt as UTC', () {
      final model = DmConversationModel.fromJson(
        baseJson(lastMessageAt: '2026-07-01T10:00:00.000Z'),
        currentUserId: 'user-1',
        profilesById: const {},
      );
      expect(model.lastMessageAt, DateTime.utc(2026, 7, 1, 10));
    });

    test('parses lastMessagePreview and lastMessageSenderId', () {
      final model = DmConversationModel.fromJson(
        baseJson(),
        currentUserId: 'user-1',
        profilesById: const {},
      );
      expect(model.lastMessagePreview, 'Hey there');
      expect(model.lastMessageSenderId, 'user-2');
    });
  });
}
