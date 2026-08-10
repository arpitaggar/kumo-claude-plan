import '../../../itinerary/data/models/itinerary_model.dart';
import '../../../itinerary/data/models/trip_segment_model.dart';
import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../../itinerary/domain/entities/trip_segment.dart';
import '../../domain/entities/itinerary_post.dart';

/// Data model for [ItineraryPost] with JSON serialization.
///
/// `snapshot` holds `items`/`segments` in the same per-item JSON shapes
/// `ItineraryItemModel`/`TripSegmentModel` already produce, so building or
/// reading a post never needs bespoke serialization for its contents.
class ItineraryPostModel extends ItineraryPost {
  const ItineraryPostModel({
    required super.id,
    required super.authorId,
    required super.authorName,
    required super.title,
    required super.startDate,
    required super.endDate,
    required super.themeKey,
    required super.currencyCode,
    required super.items,
    required super.segments,
    required super.likeCount,
    required super.likedByMe,
    required super.commentCount,
    required super.createdAt,
    super.sourceItineraryId,
    super.authorAvatarUrl,
    super.forkedFromPostId,
    super.description,
  });

  factory ItineraryPostModel.fromJson(
    Map<String, dynamic> json, {
    bool likedByMe = false,
  }) {
    final snapshot = json['snapshot'] as Map<String, dynamic>;
    return ItineraryPostModel(
      id: json['id'] as String,
      sourceItineraryId: json['source_itinerary_id'] as String?,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      forkedFromPostId: json['forked_from_post_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      themeKey: json['theme_key'] as String? ?? 'classic',
      currencyCode: json['currency_code'] as String,
      items: (snapshot['items'] as List<dynamic>? ?? [])
          .map((i) => ItineraryItemModel.fromJson(i as Map<String, dynamic>))
          .toList(),
      segments: (snapshot['segments'] as List<dynamic>? ?? [])
          .map((s) => TripSegmentModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      likeCount: _countFromJson(json, 'post_likes'),
      likedByMe: likedByMe,
      commentCount: _countFromJson(json, 'post_comments'),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Neither `like_count` (stage33) nor a comment-count equivalent
  /// (stage38) is a stored column — stage33's migration dropped the former
  /// after it caused a hot-row write-contention problem on popular posts,
  /// and comments got the same read-time-count treatment from the start.
  /// Both are counted via PostgREST's embedded-resource count syntax
  /// instead, e.g. `post_likes(count)`, which comes back as `post_likes:
  /// [{count: N}]` alongside the row. Falls back to 0 when that embed
  /// wasn't requested (e.g. `publishItinerary`'s insert-and-return, where
  /// both counts are always 0 for a just-created post anyway).
  static int _countFromJson(Map<String, dynamic> json, String embedKey) {
    final embedded = json[embedKey] as List<dynamic>?;
    if (embedded == null || embedded.isEmpty) {
      return 0;
    }
    return ((embedded.first as Map<String, dynamic>)['count'] as num?)
            ?.toInt() ??
        0;
  }

  /// Builds the row to insert when publishing [itinerary] + [segments].
  static Map<String, dynamic> buildInsertJson({
    required TravelItinerary itinerary,
    required List<TripSegment> segments,
    required String authorId,
    required String authorName,
    String? authorAvatarUrl,
  }) => {
    'source_itinerary_id': itinerary.id,
    'author_id': authorId,
    'author_name': authorName,
    if (authorAvatarUrl != null) 'author_avatar_url': authorAvatarUrl,
    if (itinerary.originPostId != null)
      'forked_from_post_id': itinerary.originPostId,
    'title': itinerary.title,
    if (itinerary.description != null) 'description': itinerary.description,
    'start_date': itinerary.startDate.toIso8601String(),
    'end_date': itinerary.endDate.toIso8601String(),
    'theme_key': itinerary.themeKey,
    'currency_code': itinerary.currencyCode,
    'snapshot': {
      'items': itinerary.items
          .map((i) => ItineraryItemModel.fromEntity(i).toJson())
          .toList(),
      'segments': segments
          .map((s) => TripSegmentModel.fromEntity(s).toJson())
          .toList(),
    },
  };
}
