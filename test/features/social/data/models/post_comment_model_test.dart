import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/social/data/models/post_comment_model.dart';

void main() {
  group('PostCommentModel.fromJson', () {
    test('parses all fields', () {
      final model = PostCommentModel.fromJson({
        'id': 'comment-1',
        'post_id': 'post-1',
        'author_id': 'user-1',
        'author_name': 'Alice',
        'author_avatar_url': 'https://example.com/a.png',
        'content': 'What a beautiful trip!',
        'created_at': '2026-06-10T00:00:00.000Z',
      });

      expect(model.id, 'comment-1');
      expect(model.postId, 'post-1');
      expect(model.authorId, 'user-1');
      expect(model.authorName, 'Alice');
      expect(model.authorAvatarUrl, 'https://example.com/a.png');
      expect(model.content, 'What a beautiful trip!');
      expect(model.createdAt, DateTime.parse('2026-06-10T00:00:00.000Z'));
    });

    test('defaults authorAvatarUrl to null when absent', () {
      final model = PostCommentModel.fromJson({
        'id': 'comment-1',
        'post_id': 'post-1',
        'author_id': 'user-1',
        'author_name': 'Alice',
        'content': 'Nice!',
        'created_at': '2026-06-10T00:00:00.000Z',
      });

      expect(model.authorAvatarUrl, isNull);
    });
  });
}
