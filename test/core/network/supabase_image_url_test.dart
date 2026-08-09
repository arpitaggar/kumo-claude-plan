import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/network/supabase_image_url.dart';

void main() {
  group('resizedImageUrl', () {
    // kImageResizingEnabled is a compile-time false const until the Supabase
    // Storage Image Transformation add-on is confirmed enabled (see the
    // constant's doc comment) — so resizedImageUrl is always a passthrough
    // today. transformObjectUrl below covers the rewrite logic itself.
    test('returns the url unchanged (kImageResizingEnabled is false)', () {
      const url =
          'https://project.supabase.co/storage/v1/object/public/avatars/uid.jpg';
      expect(resizedImageUrl(url, width: 120), url);
    });

    test('returns an empty string for a null url', () {
      expect(resizedImageUrl(null, width: 120), '');
    });
  });

  group('transformObjectUrl', () {
    test('rewrites /object/public/ to /render/image/public/ with query params', () {
      const url =
          'https://project.supabase.co/storage/v1/object/public/avatars/uid.jpg';

      final result = transformObjectUrl(url, width: 120, quality: 75);

      expect(
        result,
        'https://project.supabase.co/storage/v1/render/image/public/avatars/uid.jpg'
        '?width=120&quality=75&resize=cover',
      );
    });

    test('includes height when provided', () {
      const url =
          'https://project.supabase.co/storage/v1/object/public/avatars/uid.jpg';

      final result = transformObjectUrl(url, width: 120, height: 150);

      expect(result, contains('width=120'));
      expect(result, contains('height=150'));
    });

    test('omits height when not provided', () {
      const url =
          'https://project.supabase.co/storage/v1/object/public/avatars/uid.jpg';

      final result = transformObjectUrl(url, width: 120);

      expect(result, isNot(contains('height=')));
    });

    test('preserves nested bucket paths', () {
      const url =
          'https://project.supabase.co/storage/v1/object/public/chat-attachments/trip-1/msg-1.png';

      final result = transformObjectUrl(url, width: 360);

      expect(
        result,
        startsWith(
          'https://project.supabase.co/storage/v1/render/image/public/'
          'chat-attachments/trip-1/msg-1.png?',
        ),
      );
    });

    test('returns the url unchanged when it is not a Supabase Storage '
        'public object URL', () {
      const url = 'https://example.com/some/other/image.jpg';

      expect(transformObjectUrl(url, width: 120), url);
    });
  });
}
