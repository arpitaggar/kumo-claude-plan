import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../itinerary/data/models/itinerary_model.dart';
import '../../../itinerary/data/models/trip_segment_model.dart';
import '../../domain/entities/follow_stats.dart';
import '../../domain/repositories/social_repository.dart'
    show kSocialFeedPageSize;
import '../models/itinerary_post_model.dart';

abstract class SocialRemoteDataSource {
  /// The signed-in user's id, used to resolve `likedByMe` on fetched posts.
  String get currentUserId;

  Future<ItineraryPostModel> publishItinerary(Map<String, dynamic> insertJson);

  /// [before] fetches the page starting just before that timestamp (i.e.
  /// `created_at < before`), for keyset pagination — pass the last returned
  /// post's `createdAt` to fetch the next page. Null fetches the first page.
  Future<List<ItineraryPostModel>> fetchExplore({
    required String currentUserId,
    String? query,
    DateTime? before,
    int limit = kSocialFeedPageSize,
  });

  /// See [fetchExplore]'s [before]/[limit] doc — same keyset pagination.
  Future<List<ItineraryPostModel>> fetchFeed({
    required String currentUserId,
    DateTime? before,
    int limit = kSocialFeedPageSize,
  });

  Future<List<ItineraryPostModel>> fetchPostsByAuthor({
    required String authorId,
    required String currentUserId,
  });

  Future<ItineraryModel> forkPost({
    required String postId,
    required String newOwnerId,
    required String newOwnerName,
  });

  Future<void> toggleLike({
    required String postId,
    required String userId,
    required bool like,
  });

  Future<void> toggleFollow({
    required String followerId,
    required String followeeId,
    required bool follow,
  });

  Future<FollowStats> fetchFollowStats({
    required String userId,
    required String currentUserId,
  });

  Future<void> deletePost(String postId);
}

class SocialRemoteDataSourceImpl implements SocialRemoteDataSource {
  const SocialRemoteDataSourceImpl();

  static const _postsTable = 'itinerary_posts';
  static const _likesTable = 'post_likes';
  static const _followsTable = 'follows';
  static const _itinerariesTable = 'itineraries';
  static const _segmentsTable = 'trip_segments';

  /// `like_count` is no longer a stored column (see stage33's migration) —
  /// counted at read time via PostgREST's embedded-resource count syntax
  /// instead, so every post-fetching select asks for this.
  static const _postSelect = '*, post_likes(count)';

  /// A user following more than this many accounts still gets a feed, just
  /// capped to their most-recently-followed accounts, rather than sending an
  /// unbounded `IN (...)` list to Postgres on every feed load.
  static const _maxFolloweesPerFeed = 1000;

  @override
  String get currentUserId => KumoSupabaseClient.auth.currentUser?.id ?? '';

  Future<Set<String>> _likedPostIds(
    String currentUserId,
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) {
      return {};
    }
    final rows = await KumoSupabaseClient.client
        .from(_likesTable)
        .select('post_id')
        .eq('user_id', currentUserId)
        .inFilter('post_id', postIds);
    return (rows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['post_id'] as String)
        .toSet();
  }

  List<ItineraryPostModel> _mapWithLikes(
    List<dynamic> rows,
    Set<String> likedIds,
  ) => rows
      .cast<Map<String, dynamic>>()
      .map(
        (row) => ItineraryPostModel.fromJson(
          row,
          likedByMe: likedIds.contains(row['id'] as String),
        ),
      )
      .toList();

  @override
  Future<ItineraryPostModel> publishItinerary(
    Map<String, dynamic> insertJson,
  ) async {
    try {
      final inserted = await KumoSupabaseClient.client
          .from(_postsTable)
          .insert(insertJson)
          .select()
          .single();
      final post = ItineraryPostModel.fromJson(inserted);
      await _invokeSocialPush({'type': 'new_post', 'post_id': post.id});
      return post;
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  /// Best-effort — the like/follow/post itself has already landed via the
  /// insert above regardless of whether this succeeds. Mirrors
  /// ChatRemoteDataSourceImpl.sendMessage's invocation of send-message-push.
  Future<void> _invokeSocialPush(Map<String, dynamic> body) async {
    try {
      final res = await KumoSupabaseClient.client.functions.invoke(
        'send-social-push',
        body: body,
      );
      AppLogger.info('send-social-push: status=${res.status} data=${res.data}');
    } catch (e, st) {
      AppLogger.warning('send-social-push invoke failed: $e\n$st');
    }
  }

  @override
  Future<List<ItineraryPostModel>> fetchExplore({
    required String currentUserId,
    String? query,
    DateTime? before,
    int limit = kSocialFeedPageSize,
  }) async {
    try {
      // Fetch all filters before .order()/.limit() to stay on
      // PostgrestFilterBuilder (see profile_remote_datasource.dart's
      // searchByName for the same constraint).
      var builder = KumoSupabaseClient.client
          .from(_postsTable)
          .select(_postSelect);

      if (query != null && query.isNotEmpty) {
        // pg_trgm-backed ILIKE (stage33) searches the whole table, not just
        // whatever page happens to be fetched — unlike the old client-side
        // substring filter over a fixed 50-row page.
        final q = query.trim();
        builder = builder.or('title.ilike.%$q%,description.ilike.%$q%');
      }
      if (before != null) {
        builder = builder.lt('created_at', before.toIso8601String());
      }

      final data = await builder
          .order('created_at', ascending: false)
          .limit(limit);

      final rows = (data as List<dynamic>).cast<Map<String, dynamic>>();
      final ids = rows.map((r) => r['id'] as String).toList();
      final liked = await _likedPostIds(currentUserId, ids);
      return _mapWithLikes(rows, liked);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<ItineraryPostModel>> fetchFeed({
    required String currentUserId,
    DateTime? before,
    int limit = kSocialFeedPageSize,
  }) async {
    try {
      final followRows = await KumoSupabaseClient.client
          .from(_followsTable)
          .select('followee_id')
          .eq('follower_id', currentUserId)
          .order('created_at', ascending: false)
          .limit(_maxFolloweesPerFeed);
      final followeeIds = (followRows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['followee_id'] as String)
          .toList();

      if (followeeIds.isEmpty) {
        return [];
      }

      var builder = KumoSupabaseClient.client
          .from(_postsTable)
          .select(_postSelect)
          .inFilter('author_id', followeeIds);
      if (before != null) {
        builder = builder.lt('created_at', before.toIso8601String());
      }

      final data = await builder
          .order('created_at', ascending: false)
          .limit(limit);

      final rows = (data as List<dynamic>).cast<Map<String, dynamic>>();
      final ids = rows.map((r) => r['id'] as String).toList();
      final liked = await _likedPostIds(currentUserId, ids);
      return _mapWithLikes(rows, liked);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<ItineraryPostModel>> fetchPostsByAuthor({
    required String authorId,
    required String currentUserId,
  }) async {
    try {
      final data = await KumoSupabaseClient.client
          .from(_postsTable)
          .select(_postSelect)
          .eq('author_id', authorId)
          .order('created_at', ascending: false);

      final rows = data as List<dynamic>;
      final ids = rows
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toList();
      final liked = await _likedPostIds(currentUserId, ids);
      return _mapWithLikes(rows, liked);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<ItineraryModel> forkPost({
    required String postId,
    required String newOwnerId,
    required String newOwnerName,
  }) async {
    try {
      final postRow = await KumoSupabaseClient.client
          .from(_postsTable)
          .select(_postSelect)
          .eq('id', postId)
          .single();
      final post = ItineraryPostModel.fromJson(postRow);

      final now = DateTime.now().toUtc();
      final newItineraryId = const Uuid().v4();

      final itineraryJson = {
        'id': newItineraryId,
        'title': post.title,
        'owner_id': newOwnerId,
        'start_date': post.startDate.toIso8601String(),
        'end_date': post.endDate.toIso8601String(),
        'total_budget': 0,
        'currency_code': post.currencyCode,
        'members': [
          {
            'user_id': newOwnerId,
            'user_name': newOwnerName,
            'role': 'owner',
            'joined_at': now.toIso8601String(),
          },
        ],
        'items': post.items
            .map((i) => ItineraryItemModel.fromEntity(i).toJson())
            .toList(),
        'expense_summary': {
          'total_spent': 0,
          'spent_by_category': <String, dynamic>{},
          'member_balances': <String, dynamic>{},
        },
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'description': post.description,
        'is_public': false,
        'theme_key': post.themeKey,
        'origin_post_id': postId,
      };

      final insertedItinerary = await KumoSupabaseClient.client
          .from(_itinerariesTable)
          .insert(itineraryJson)
          .select()
          .single();

      if (post.segments.isNotEmpty) {
        final segmentRows = post.segments
            .map(
              (s) => TripSegmentModel.fromEntity(s.copyWith()).toJson()
                ..['id'] = const Uuid().v4()
                ..['itinerary_id'] = newItineraryId,
            )
            .toList();
        await KumoSupabaseClient.client
            .from(_segmentsTable)
            .insert(segmentRows);
      }

      return ItineraryModel.fromJson(insertedItinerary);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> toggleLike({
    required String postId,
    required String userId,
    required bool like,
  }) async {
    try {
      if (like) {
        await KumoSupabaseClient.client.from(_likesTable).upsert({
          'post_id': postId,
          'user_id': userId,
        });
        await _invokeSocialPush({'type': 'like', 'post_id': postId});
      } else {
        await KumoSupabaseClient.client
            .from(_likesTable)
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      }
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> toggleFollow({
    required String followerId,
    required String followeeId,
    required bool follow,
  }) async {
    try {
      if (follow) {
        await KumoSupabaseClient.client.from(_followsTable).upsert({
          'follower_id': followerId,
          'followee_id': followeeId,
        });
        await _invokeSocialPush({'type': 'follow', 'followee_id': followeeId});
      } else {
        await KumoSupabaseClient.client
            .from(_followsTable)
            .delete()
            .eq('follower_id', followerId)
            .eq('followee_id', followeeId);
      }
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<FollowStats> fetchFollowStats({
    required String userId,
    required String currentUserId,
  }) async {
    try {
      final followers = await KumoSupabaseClient.client
          .from(_followsTable)
          .select('follower_id')
          .eq('followee_id', userId);
      final following = await KumoSupabaseClient.client
          .from(_followsTable)
          .select('followee_id')
          .eq('follower_id', userId);

      final isFollowedByMe = (followers as List<dynamic>).any(
        (r) => (r as Map<String, dynamic>)['follower_id'] == currentUserId,
      );

      return FollowStats(
        followerCount: followers.length,
        followingCount: (following as List<dynamic>).length,
        isFollowedByMe: isFollowedByMe,
      );
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      await KumoSupabaseClient.client
          .from(_postsTable)
          .delete()
          .eq('id', postId);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }
}
