import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/direct_messages/data/models/direct_message_model.dart';

void main() {
  const createdAt = '2026-07-01T10:00:00.000Z';

  Map<String, dynamic> baseJson({List<String>? readBy}) => {
    'id': 'msg-1',
    'dm_conversation_id': 'conv-1',
    'sender_id': 'user-1',
    'sender_name': 'Alice',
    'content': 'Hello!',
    'created_at': createdAt,
    'read_by': readBy,
  };

  group('DirectMessageModel.fromJson', () {
    test('parses all standard fields', () {
      final model = DirectMessageModel.fromJson(baseJson());
      expect(model.id, 'msg-1');
      expect(model.dmConversationId, 'conv-1');
      expect(model.senderId, 'user-1');
      expect(model.senderName, 'Alice');
      expect(model.content, 'Hello!');
      expect(model.createdAt, DateTime.utc(2026, 7, 1, 10));
    });

    test('defaults readBy to empty list when key is null', () {
      final model = DirectMessageModel.fromJson(baseJson());
      expect(model.readBy, isEmpty);
    });

    test('parses read_by array correctly', () {
      final model = DirectMessageModel.fromJson(baseJson(readBy: ['user-2']));
      expect(model.readBy, ['user-2']);
    });

    test('createdAt is UTC', () {
      final model = DirectMessageModel.fromJson(baseJson());
      expect(model.createdAt.isUtc, isTrue);
    });

    test('senderId defaults to empty string (defensive — always set on a real '
        'DM row by messages_dm_participant_insert) when sender_id is null', () {
      final json = baseJson()..['sender_id'] = null;
      final model = DirectMessageModel.fromJson(json);
      expect(model.senderId, '');
    });
  });

  group('DirectMessageModel.toJson', () {
    test('round-trips through fromJson/toJson', () {
      final original = baseJson(readBy: ['user-2']);
      final model = DirectMessageModel.fromJson(original);
      final json = model.toJson();
      expect(json['dm_conversation_id'], original['dm_conversation_id']);
      expect(json['content'], original['content']);
      expect(json['sender_id'], original['sender_id']);
      expect(json['read_by'], original['read_by']);
    });
  });
}
