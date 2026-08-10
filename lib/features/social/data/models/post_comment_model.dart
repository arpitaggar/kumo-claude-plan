import '../../domain/entities/post_comment.dart';

class PostCommentModel extends PostComment {
  const PostCommentModel({
    required super.id,
    required super.postId,
    required super.authorId,
    required super.authorName,
    required super.content,
    required super.createdAt,
    super.authorAvatarUrl,
  });

  factory PostCommentModel.fromJson(Map<String, dynamic> json) =>
      PostCommentModel(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        authorId: json['author_id'] as String,
        authorName: json['author_name'] as String,
        authorAvatarUrl: json['author_avatar_url'] as String?,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
