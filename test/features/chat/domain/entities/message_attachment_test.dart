import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/chat/domain/entities/message_attachment.dart';

void main() {
  group('isImage', () {
    test('is true when kind is AttachmentKind.image', () {
      const attachment = MessageAttachment(
        id: 'a1',
        kind: AttachmentKind.image,
        url: 'https://example.com/a.jpg',
        fileName: 'a.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 100,
      );

      expect(attachment.isImage, isTrue);
    });

    test('is false when kind is AttachmentKind.file', () {
      const attachment = MessageAttachment(
        id: 'a1',
        kind: AttachmentKind.file,
        url: 'https://example.com/a.pdf',
        fileName: 'a.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 100,
      );

      expect(attachment.isImage, isFalse);
    });
  });
}
