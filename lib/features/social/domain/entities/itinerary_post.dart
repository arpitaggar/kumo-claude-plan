import 'package:equatable/equatable.dart';

import '../../../itinerary/domain/entities/travel_itinerary.dart';
import '../../../itinerary/domain/entities/trip_segment.dart';

/// An immutable snapshot of an itinerary, published to the public feed.
///
/// Publishing writes a new row here rather than flipping a visibility flag
/// on the live [TravelItinerary] — editing your itinerary after publishing
/// does not change what's already public. Publishing again creates another
/// [ItineraryPost]; it does not mutate this one.
class ItineraryPost extends Equatable {
  const ItineraryPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.themeKey,
    required this.currencyCode,
    required this.items,
    required this.segments,
    required this.likeCount,
    required this.likedByMe,
    required this.commentCount,
    required this.createdAt,
    this.sourceItineraryId,
    this.authorAvatarUrl,
    this.forkedFromPostId,
    this.description,
  });

  final String id;

  /// The itinerary this post was snapshotted from. May point at a since
  /// deleted or further-edited itinerary — the post itself never changes.
  final String? sourceItineraryId;

  final String authorId;

  /// Denormalised at publish time so a post still renders correctly even if
  /// the author later changes their name or avatar.
  final String authorName;
  final String? authorAvatarUrl;

  /// The post this one was forked from, if the source itinerary was created
  /// via `ForkPostUseCase`. Null for an original publish.
  final String? forkedFromPostId;

  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String themeKey;
  final String currencyCode;

  /// Snapshot of the itinerary's items at publish time.
  final List<ItineraryItem> items;

  /// Snapshot of the itinerary's route segments at publish time.
  final List<TripSegment> segments;

  final int likeCount;

  /// Whether the current user has liked this post.
  final bool likedByMe;

  final int commentCount;

  final DateTime createdAt;

  ItineraryPost copyWith({
    int? likeCount,
    bool? likedByMe,
    int? commentCount,
  }) => ItineraryPost(
    id: id,
    sourceItineraryId: sourceItineraryId,
    authorId: authorId,
    authorName: authorName,
    authorAvatarUrl: authorAvatarUrl,
    forkedFromPostId: forkedFromPostId,
    title: title,
    description: description,
    startDate: startDate,
    endDate: endDate,
    themeKey: themeKey,
    currencyCode: currencyCode,
    items: items,
    segments: segments,
    likeCount: likeCount ?? this.likeCount,
    likedByMe: likedByMe ?? this.likedByMe,
    commentCount: commentCount ?? this.commentCount,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    sourceItineraryId,
    authorId,
    authorName,
    authorAvatarUrl,
    forkedFromPostId,
    title,
    description,
    startDate,
    endDate,
    themeKey,
    currencyCode,
    items,
    segments,
    likeCount,
    likedByMe,
    commentCount,
    createdAt,
  ];
}
