import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/chat/data/models/message_model.dart';
import 'package:kumo_claude/features/chat/domain/entities/message.dart';

void main() {
  const createdAt = '2026-07-01T10:00:00.000Z';

  Map<String, dynamic> baseJson({List<String>? readBy}) => {
    'id': 'msg-1',
    'itinerary_id': 'trip-1',
    'sender_id': 'user-1',
    'sender_name': 'Alice',
    'content': 'Hello!',
    'created_at': createdAt,
    'read_by': readBy, // null handled by fromJson → defaults to []
  };

  group('Message entity', () {
    test('readBy defaults to empty list', () {
      final msg = Message(
        id: 'msg-1',
        itineraryId: 'trip-1',
        senderId: 'user-1',
        senderName: 'Alice',
        content: 'Hello',
        createdAt: DateTime(2026, 7),
      );
      expect(msg.readBy, isEmpty);
    });

    test('readBy is included in equality props', () {
      final base = Message(
        id: 'msg-1',
        itineraryId: 'trip-1',
        senderId: 'user-1',
        senderName: 'Alice',
        content: 'Hello',
        createdAt: DateTime(2026, 7),
      );
      final withRead = Message(
        id: 'msg-1',
        itineraryId: 'trip-1',
        senderId: 'user-1',
        senderName: 'Alice',
        content: 'Hello',
        createdAt: DateTime(2026, 7),
        readBy: const ['user-2'],
      );
      expect(base, isNot(equals(withRead)));
    });
  });

  group('MessageModel.fromJson', () {
    test('parses all standard fields', () {
      final model = MessageModel.fromJson(baseJson());
      expect(model.id, 'msg-1');
      expect(model.itineraryId, 'trip-1');
      expect(model.senderId, 'user-1');
      expect(model.senderName, 'Alice');
      expect(model.content, 'Hello!');
      expect(model.createdAt, DateTime.utc(2026, 7, 1, 10));
    });

    test('defaults readBy to empty list when key absent', () {
      final model = MessageModel.fromJson(baseJson());
      expect(model.readBy, isEmpty);
    });

    test('defaults readBy to empty list when key is null', () {
      final json = baseJson()..['read_by'] = null;
      final model = MessageModel.fromJson(json);
      expect(model.readBy, isEmpty);
    });

    test('parses read_by array correctly', () {
      final model = MessageModel.fromJson(
        baseJson(readBy: ['user-2', 'user-3']),
      );
      expect(model.readBy, ['user-2', 'user-3']);
    });

    test('parses empty read_by array', () {
      final model = MessageModel.fromJson(baseJson(readBy: []));
      expect(model.readBy, isEmpty);
    });

    test('defaults senderName to empty string when absent', () {
      final json = baseJson()..remove('sender_name');
      final model = MessageModel.fromJson(json);
      expect(model.senderName, '');
    });

    test('createdAt is UTC', () {
      final model = MessageModel.fromJson(baseJson());
      expect(model.createdAt.isUtc, isTrue);
    });

    test('falls back to hitchhiker_id for senderId when sender_id is null '
        '(Hitchhiker-authored message, see stage45_hitchhikers.sql)', () {
      final json = baseJson()
        ..['sender_id'] = null
        ..['sender_name'] = 'Priya'
        ..['hitchhiker_id'] = 'hh-1';
      final model = MessageModel.fromJson(json);
      expect(model.senderId, 'hh-1');
      expect(model.senderName, 'Priya');
    });

    test(
      'two different Hitchhikers on the same trip get distinct senderIds',
      () {
        final first = MessageModel.fromJson(
          baseJson()
            ..['sender_id'] = null
            ..['hitchhiker_id'] = 'hh-1',
        );
        final second = MessageModel.fromJson(
          baseJson()
            ..['sender_id'] = null
            ..['hitchhiker_id'] = 'hh-2',
        );
        expect(first.senderId, isNot(equals(second.senderId)));
      },
    );

    test('senderId is an empty string, not a crash, when both sender_id and '
        'hitchhiker_id are absent', () {
      final json = baseJson()..['sender_id'] = null;
      final model = MessageModel.fromJson(json);
      expect(model.senderId, '');
    });
  });

  group('MessageModel.toJson', () {
    test('includes read_by in output', () {
      final model = MessageModel.fromJson(baseJson(readBy: ['user-2']));
      final json = model.toJson();
      expect(json['read_by'], ['user-2']);
    });

    test('serialises empty readBy as empty list', () {
      final model = MessageModel.fromJson(baseJson());
      final json = model.toJson();
      expect(json['read_by'], isEmpty);
    });

    test('round-trips through fromJson/toJson', () {
      final original = baseJson(readBy: ['user-2', 'user-3']);
      final model = MessageModel.fromJson(original);
      final json = model.toJson();
      expect(json['read_by'], original['read_by']);
      expect(json['content'], original['content']);
      expect(json['sender_id'], original['sender_id']);
    });
  });
}
