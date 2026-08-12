import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/network/signed_storage_url.dart';

void main() {
  group('parseStorageObjectUrl', () {
    test('splits a simple bucket/path URL', () {
      const url =
          'https://project.supabase.co/storage/v1/object/public/avatars/uid/avatar.jpg';

      final result = parseStorageObjectUrl(url);

      expect(result, isNotNull);
      expect(result!.bucket, 'avatars');
      expect(result.path, 'uid/avatar.jpg');
    });

    test('preserves nested paths under the bucket', () {
      const url =
          'https://project.supabase.co/storage/v1/object/public/chat-attachments/trip-1/msg-1.png';

      final result = parseStorageObjectUrl(url);

      expect(result!.bucket, 'chat-attachments');
      expect(result.path, 'trip-1/msg-1.png');
    });

    test('strips a query string (e.g. the avatar cache-bust param)', () {
      const url =
          'https://project.supabase.co/storage/v1/object/public/avatars/'
          'uid/avatar.jpg?t=1234567890';

      final result = parseStorageObjectUrl(url);

      expect(result!.bucket, 'avatars');
      expect(result.path, 'uid/avatar.jpg');
    });

    test('returns null for a URL that is not a Supabase Storage public '
        'object URL', () {
      expect(
        parseStorageObjectUrl('https://example.com/some/image.jpg'),
        isNull,
      );
    });

    test('returns null when the URL has a bucket segment but no path', () {
      const url =
          'https://project.supabase.co/storage/v1/object/public/avatars';

      expect(parseStorageObjectUrl(url), isNull);
    });
  });
}
