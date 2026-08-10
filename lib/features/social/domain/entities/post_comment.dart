import 'package:equatable/equatable.dart';

/// One comment on a published [ItineraryPost][../entities/itinerary_post.dart].
/// Flat, non-threaded — no reply-to-a-comment structure.
class PostComment extends Equatable {
  const PostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.authorAvatarUrl,
  });

  final String id;
  final String postId;
  final String authorId;

  /// Denormalised at insert time — see `ItineraryPost.authorName`'s doc for
  /// the same rationale (renders without a join, survives a rename).
  final String authorName;
  final String? authorAvatarUrl;

  final String content;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    postId,
    authorId,
    authorName,
    authorAvatarUrl,
    content,
    createdAt,
  ];
}
