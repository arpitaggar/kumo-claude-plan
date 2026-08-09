import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/chat/data/models/message_attachment_model.dart';
import 'package:kumo_claude/features/chat/data/models/message_read_receipt_model.dart';

void main() {
  group('MessageAttachmentModel.fromJson', () {
    test('parses all fields, remapping public_url to url', () {
      final model = MessageAttachmentModel.fromJson({
        'id': 'a1',
        'kind': 'image',
        'public_url': 'https://example.com/a.jpg',
        'file_name': 'a.jpg',
        'mime_type': 'image/jpeg',
        'size_bytes': 12345,
      });

      expect(model.id, 'a1');
      expect(model.kind, 'image');
      expect(model.url, 'https://example.com/a.jpg');
      expect(model.fileName, 'a.jpg');
      expect(model.mimeType, 'image/jpeg');
      expect(model.sizeBytes, 12345);
    });

    test('coerces a double size_bytes to int', () {
      final model = MessageAttachmentModel.fromJson({
        'id': 'a1',
        'kind': 'file',
        'public_url': 'https://example.com/a.pdf',
        'file_name': 'a.pdf',
        'mime_type': 'application/pdf',
        'size_bytes': 100.0,
      });

      expect(model.sizeBytes, 100);
      expect(model.sizeBytes, isA<int>());
    });
  });

  group('MessageReadReceiptModel.fromJson', () {
    test('parses all fields', () {
      final model = MessageReadReceiptModel.fromJson({
        'user_id': 'user-1',
        'display_name': 'Alice',
        'avatar_url': 'https://example.com/a.png',
        'read_at': '2026-06-01T12:00:00.000Z',
      });

      expect(model.userId, 'user-1');
      expect(model.displayName, 'Alice');
      expect(model.avatarUrl, 'https://example.com/a.png');
      expect(model.readAt, DateTime.utc(2026, 6, 1, 12));
    });

    test('defaults displayName to empty string when absent', () {
      final model = MessageReadReceiptModel.fromJson({
        'user_id': 'user-1',
        'read_at': '2026-06-01T12:00:00.000Z',
      });

      expect(model.displayName, '');
    });

    test('leaves avatarUrl null when absent', () {
      final model = MessageReadReceiptModel.fromJson({
        'user_id': 'user-1',
        'display_name': 'Alice',
        'read_at': '2026-06-01T12:00:00.000Z',
      });

      expect(model.avatarUrl, isNull);
    });
  });
}
