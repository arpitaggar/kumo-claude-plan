import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/social/domain/entities/follow_stats.dart';
import 'package:kumo_claude/features/social/domain/entities/itinerary_post.dart';
import 'package:kumo_claude/features/social/domain/repositories/social_repository.dart';
import 'package:kumo_claude/features/social/domain/usecases/fetch_explore_posts_usecase.dart';
import 'package:kumo_claude/features/social/domain/usecases/fetch_follow_stats_usecase.dart';
import 'package:kumo_claude/features/social/domain/usecases/fetch_following_feed_usecase.dart';
import 'package:kumo_claude/features/social/domain/usecases/fetch_posts_by_author_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  late MockSocialRepository mockRepo;

  final tPost = ItineraryPost(
    id: 'post-1',
    authorId: 'user-1',
    authorName: 'Alice',
    title: 'Tokyo Summer 2026',
    startDate: DateTime.utc(2026, 6),
    endDate: DateTime.utc(2026, 6, 7),
    themeKey: 'classic',
    currencyCode: 'JPY',
    items: const [],
    segments: const [],
    likeCount: 0,
    likedByMe: false,
    commentCount: 0,
    createdAt: DateTime.utc(2026, 6, 10),
  );

  setUp(() {
    mockRepo = MockSocialRepository();
  });

  group('FetchExplorePostsUseCase', () {
    test(
      'passes the query through and returns the repository result',
      () async {
        when(
          () => mockRepo.fetchExplore(query: 'Tokyo'),
        ).thenAnswer((_) async => Right([tPost]));

        final result = await FetchExplorePostsUseCase(
          mockRepo,
        ).call(query: 'Tokyo');

        verify(() => mockRepo.fetchExplore(query: 'Tokyo')).called(1);
        expect(result.isRight(), isTrue);
      },
    );

    test('defaults query to null', () async {
      when(
        () => mockRepo.fetchExplore(),
      ).thenAnswer((_) async => Right([tPost]));

      await FetchExplorePostsUseCase(mockRepo).call();

      verify(() => mockRepo.fetchExplore()).called(1);
    });
  });

  group('FetchFollowingFeedUseCase', () {
    test('delegates with currentUserId', () async {
      when(
        () => mockRepo.fetchFeed(currentUserId: 'user-1'),
      ).thenAnswer((_) async => Right([tPost]));

      final result = await FetchFollowingFeedUseCase(
        mockRepo,
      ).call(currentUserId: 'user-1');

      verify(() => mockRepo.fetchFeed(currentUserId: 'user-1')).called(1);
      expect(result.isRight(), isTrue);
    });
  });

  group('FetchPostsByAuthorUseCase', () {
    test('delegates with authorId', () async {
      when(
        () => mockRepo.fetchPostsByAuthor('user-1'),
      ).thenAnswer((_) async => Right([tPost]));

      final result = await FetchPostsByAuthorUseCase(mockRepo).call('user-1');

      verify(() => mockRepo.fetchPostsByAuthor('user-1')).called(1);
      expect(result.isRight(), isTrue);
    });

    test('propagates ServerFailure', () async {
      when(
        () => mockRepo.fetchPostsByAuthor(any()),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await FetchPostsByAuthorUseCase(mockRepo).call('user-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('FetchFollowStatsUseCase', () {
    test('delegates with userId/currentUserId', () async {
      const stats = FollowStats(
        followerCount: 3,
        followingCount: 5,
        isFollowedByMe: true,
      );
      when(
        () => mockRepo.fetchFollowStats(
          userId: 'user-2',
          currentUserId: 'user-1',
        ),
      ).thenAnswer((_) async => const Right(stats));

      final result = await FetchFollowStatsUseCase(
        mockRepo,
      ).call(userId: 'user-2', currentUserId: 'user-1');

      verify(
        () => mockRepo.fetchFollowStats(
          userId: 'user-2',
          currentUserId: 'user-1',
        ),
      ).called(1);
      result.fold(
        (_) => fail('expected Right'),
        (s) => expect(s.followerCount, 3),
      );
    });
  });
}
