import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../itinerary/data/models/itinerary_model.dart';
import '../../../itinerary/data/models/trip_segment_model.dart';
import '../../domain/entities/follow_stats.dart';
import '../models/itinerary_post_model.dart';

abstract class SocialRemoteDataSource {
  /// The signed-in user's id, used to resolve `likedByMe` on fetched posts.
  String get currentUserId;

  Future<ItineraryPostModel> publishItinerary(Map<String, dynamic> insertJson);

  Future<List<ItineraryPostModel>> fetchExplore({
    required String currentUserId,
    String? query,
  });

  Future<List<ItineraryPostModel>> fetchFeed({required String currentUserId});

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
}

class SocialRemoteDataSourceImpl implements SocialRemoteDataSource {
  const SocialRemoteDataSourceImpl();

  static const _postsTable = 'itinerary_posts';
  static const _likesTable = 'post_likes';
  static const _followsTable = 'follows';
  static const _itinerariesTable = 'itineraries';
  static const _segmentsTable = 'trip_segments';

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
      return ItineraryPostModel.fromJson(inserted);
    } on sb.PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnexpectedException(message: e.toString());
    }
  }

  @override
  Future<List<ItineraryPostModel>> fetchExplore({
    required String currentUserId,
    String? query,
  }) async {
    try {
      final data = await KumoSupabaseClient.client
          .from(_postsTable)
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      var rows = data as List<dynamic>;
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        rows = rows.where((r) {
          final row = r as Map<String, dynamic>;
          final title = (row['title'] as String? ?? '').toLowerCase();
          final description =
              (row['description'] as String? ?? '').toLowerCase();
          return title.contains(q) || description.contains(q);
        }).toList();
      }

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
  Future<List<ItineraryPostModel>> fetchFeed({
    required String currentUserId,
  }) async {
    try {
      final followRows = await KumoSupabaseClient.client
          .from(_followsTable)
          .select('followee_id')
          .eq('follower_id', currentUserId);
      final followeeIds = (followRows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['followee_id'] as String)
          .toList();

      if (followeeIds.isEmpty) {
        return [];
      }

      final data = await KumoSupabaseClient.client
          .from(_postsTable)
          .select()
          .inFilter('author_id', followeeIds)
          .order('created_at', ascending: false)
          .limit(100);

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
  Future<List<ItineraryPostModel>> fetchPostsByAuthor({
    required String authorId,
    required String currentUserId,
  }) async {
    try {
      final data = await KumoSupabaseClient.client
          .from(_postsTable)
          .select()
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
          .select()
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
              (s) => TripSegmentModel.fromEntity(
                s.copyWith(),
              ).toJson()
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
}
