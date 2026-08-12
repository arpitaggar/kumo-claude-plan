import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/data/models/itinerary_model.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/social/data/datasources/social_remote_datasource.dart';
import 'package:kumo_claude/features/social/data/models/itinerary_post_model.dart';
import 'package:kumo_claude/features/social/data/models/post_comment_model.dart';
import 'package:kumo_claude/features/social/data/repositories/social_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockSocialRemoteDataSource extends Mock
    implements SocialRemoteDataSource {}

void main() {
  late MockSocialRemoteDataSource dataSource;
  late SocialRepositoryImpl repository;

  final tPost = ItineraryPostModel(
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

  final tItinerary = TravelItinerary(
    id: 'it-1',
    title: 'Tokyo Summer 2026',
    ownerId: 'user-2',
    startDate: DateTime.utc(2026, 6),
    endDate: DateTime.utc(2026, 6, 7),
    totalBudget: 0,
    currencyCode: 'JPY',
    members: const [],
    items: const [],
    expenseSummary: const ExpenseSummary(
      totalSpent: 0,
      spentByCategory: {},
      memberBalances: {},
    ),
    createdAt: DateTime.utc(2026, 6, 10),
    updatedAt: DateTime.utc(2026, 6, 10),
  );

  setUp(() {
    dataSource = MockSocialRemoteDataSource();
    repository = SocialRepositoryImpl(dataSource);
    when(() => dataSource.currentUserId).thenReturn('user-2');
  });

  group('publishItinerary', () {
    test('returns Right(post) on success', () async {
      when(
        () => dataSource.publishItinerary(any()),
      ).thenAnswer((_) async => tPost);

      final result = await repository.publishItinerary(
        itinerary: tItinerary,
        segments: const [],
        authorName: 'Alice',
      );

      result.fold((_) => fail('expected Right'), (post) => expect(post, tPost));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.publishItinerary(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.publishItinerary(
        itinerary: tItinerary,
        segments: const [],
        authorName: 'Alice',
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('fetchExplore', () {
    test(
      'resolves currentUserId from the data source and forwards params',
      () async {
        final before = DateTime.utc(2026, 1, 1);
        when(
          () => dataSource.fetchExplore(
            currentUserId: any(named: 'currentUserId'),
            query: any(named: 'query'),
            before: any(named: 'before'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [tPost]);

        final result = await repository.fetchExplore(
          query: 'Tokyo',
          before: before,
          limit: 10,
        );

        verify(
          () => dataSource.fetchExplore(
            currentUserId: 'user-2',
            query: 'Tokyo',
            before: before,
            limit: 10,
          ),
        ).called(1);
        result.fold(
          (_) => fail('expected Right'),
          (posts) => expect(posts, [tPost]),
        );
      },
    );

    test('maps NetworkException to NetworkFailure', () async {
      when(
        () => dataSource.fetchExplore(
          currentUserId: any(named: 'currentUserId'),
          query: any(named: 'query'),
          before: any(named: 'before'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(NetworkException.noInternet());

      final result = await repository.fetchExplore();

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('fetchFeed', () {
    test('forwards currentUserId/before/limit to the data source', () async {
      final before = DateTime.utc(2026, 1, 1);
      when(
        () => dataSource.fetchFeed(
          currentUserId: any(named: 'currentUserId'),
          before: any(named: 'before'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [tPost]);

      final result = await repository.fetchFeed(
        currentUserId: 'user-1',
        before: before,
        limit: 5,
      );

      verify(
        () => dataSource.fetchFeed(
          currentUserId: 'user-1',
          before: before,
          limit: 5,
        ),
      ).called(1);
      result.fold(
        (_) => fail('expected Right'),
        (posts) => expect(posts, [tPost]),
      );
    });

    test('maps an unexpected exception to UnexpectedFailure', () async {
      when(
        () => dataSource.fetchFeed(
          currentUserId: any(named: 'currentUserId'),
          before: any(named: 'before'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(Exception('boom'));

      final result = await repository.fetchFeed(currentUserId: 'user-1');

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('fetchPostsByAuthor', () {
    test('resolves currentUserId and forwards authorId', () async {
      when(
        () => dataSource.fetchPostsByAuthor(
          authorId: any(named: 'authorId'),
          currentUserId: any(named: 'currentUserId'),
        ),
      ).thenAnswer((_) async => [tPost]);

      final result = await repository.fetchPostsByAuthor('user-1');

      verify(
        () => dataSource.fetchPostsByAuthor(
          authorId: 'user-1',
          currentUserId: 'user-2',
        ),
      ).called(1);
      expect(result.isRight(), isTrue);
    });
  });

  group('forkPost', () {
    test('returns Right(itinerary) on success', () async {
      when(
        () => dataSource.forkPost(
          postId: any(named: 'postId'),
          newOwnerId: any(named: 'newOwnerId'),
          newOwnerName: any(named: 'newOwnerName'),
        ),
      ).thenAnswer((_) async => ItineraryModel.fromEntity(tItinerary));

      final result = await repository.forkPost(
        postId: 'post-1',
        newOwnerId: 'user-1',
        newOwnerName: 'Alice',
      );

      result.fold((_) => fail('expected Right'), (it) => expect(it.id, 'it-1'));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.forkPost(
          postId: any(named: 'postId'),
          newOwnerId: any(named: 'newOwnerId'),
          newOwnerName: any(named: 'newOwnerName'),
        ),
      ).thenThrow(ServerException(message: 'not found'));

      final result = await repository.forkPost(
        postId: 'post-1',
        newOwnerId: 'user-1',
        newOwnerName: 'Alice',
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('toggleLike', () {
    test('returns Right(null) on success', () async {
      when(
        () => dataSource.toggleLike(
          postId: any(named: 'postId'),
          userId: any(named: 'userId'),
          like: any(named: 'like'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.toggleLike(
        postId: 'post-1',
        userId: 'user-1',
        like: true,
      );

      expect(result, const Right<Failure, void>(null));
    });
  });

  group('deletePost', () {
    test('returns Right(null) on success', () async {
      when(() => dataSource.deletePost(any())).thenAnswer((_) async {});

      final result = await repository.deletePost('post-1');

      expect(result, const Right<Failure, void>(null));
      verify(() => dataSource.deletePost('post-1')).called(1);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.deletePost(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.deletePost('post-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('watchComments', () {
    final tComment = PostCommentModel(
      id: 'comment-1',
      postId: 'post-1',
      authorId: 'user-1',
      authorName: 'Alice',
      content: 'Nice trip!',
      createdAt: DateTime.utc(2026, 6, 10),
    );

    test('maps a data-source stream to Right', () async {
      when(
        () => dataSource.watchComments('post-1'),
      ).thenAnswer((_) => Stream.value([tComment]));

      final result = await repository.watchComments('post-1').first;

      result.fold(
        (_) => fail('expected Right'),
        (comments) => expect(comments, [tComment]),
      );
    });

    test(
      'maps a stream error to Left(Failure) instead of dropping it',
      () async {
        when(() => dataSource.watchComments('post-1')).thenAnswer(
          (_) => Stream<List<PostCommentModel>>.error(
            ServerException(message: 'connection lost'),
          ),
        );

        final result = await repository.watchComments('post-1').first;

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });

  group('addComment', () {
    test('builds the insert JSON and returns Right(null) on success', () async {
      when(() => dataSource.addComment(any())).thenAnswer((_) async {});

      final result = await repository.addComment(
        postId: 'post-1',
        authorId: 'user-1',
        authorName: 'Alice',
        content: 'Nice trip!',
        authorAvatarUrl: 'https://example.com/a.png',
      );

      expect(result, const Right<Failure, void>(null));
      final captured =
          verify(() => dataSource.addComment(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['post_id'], 'post-1');
      expect(captured['author_id'], 'user-1');
      expect(captured['author_name'], 'Alice');
      expect(captured['author_avatar_url'], 'https://example.com/a.png');
      expect(captured['content'], 'Nice trip!');
    });

    test('omits author_avatar_url when not provided', () async {
      when(() => dataSource.addComment(any())).thenAnswer((_) async {});

      await repository.addComment(
        postId: 'post-1',
        authorId: 'user-1',
        authorName: 'Alice',
        content: 'Nice trip!',
      );

      final captured =
          verify(() => dataSource.addComment(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured.containsKey('author_avatar_url'), isFalse);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.addComment(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.addComment(
        postId: 'post-1',
        authorId: 'user-1',
        authorName: 'Alice',
        content: 'Nice trip!',
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('deleteComment', () {
    test('returns Right(null) on success', () async {
      when(() => dataSource.deleteComment(any())).thenAnswer((_) async {});

      final result = await repository.deleteComment('comment-1');

      expect(result, const Right<Failure, void>(null));
      verify(() => dataSource.deleteComment('comment-1')).called(1);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.deleteComment(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.deleteComment('comment-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
