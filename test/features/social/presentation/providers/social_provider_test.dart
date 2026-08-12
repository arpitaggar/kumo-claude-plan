import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/social/domain/entities/itinerary_post.dart';
import 'package:kumo_claude/features/social/domain/repositories/social_repository.dart';
import 'package:kumo_claude/features/social/domain/usecases/fetch_explore_posts_usecase.dart';
import 'package:kumo_claude/features/social/domain/usecases/fetch_following_feed_usecase.dart';
import 'package:kumo_claude/features/social/presentation/providers/social_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

/// Builds a real `AuthNotifier` (its constructor is what actually resolves
/// `authNotifierProvider`'s state via `getCurrentUser()`) backed by a mocked
/// repository, so `followingFeedProvider`'s `ref.watch(authNotifierProvider)`
/// dependency resolves the same way it does in the running app.
AuthNotifier _buildAuthNotifier(User? currentUser) {
  final repo = MockAuthRepository();
  when(repo.getCurrentUser).thenAnswer((_) async => Right(currentUser));
  return AuthNotifier(
    loginUseCase: MockLoginUseCase(),
    signupUseCase: MockSignupUseCase(),
    logoutUseCase: MockLogoutUseCase(),
    deleteAccountUseCase: MockDeleteAccountUseCase(),
    repository: repo,
  );
}

ItineraryPost _post(String id, DateTime createdAt) => ItineraryPost(
  id: id,
  authorId: 'author-1',
  authorName: 'Alice',
  title: 'Trip $id',
  startDate: createdAt,
  endDate: createdAt,
  themeKey: 'classic',
  currencyCode: 'USD',
  items: const [],
  segments: const [],
  likeCount: 0,
  likedByMe: false,
  commentCount: 0,
  createdAt: createdAt,
);

/// A full page's worth of posts (matches kSocialFeedPageSize) so
/// `hasMore` heuristics behave as they would against a real backend.
List<ItineraryPost> _fullPage({required int startingAt}) => [
  for (var i = 0; i < kSocialFeedPageSize; i++)
    _post(
      'post-${startingAt + i}',
      DateTime.utc(2026, 6, 1, 0, -(startingAt + i)),
    ),
];

void main() {
  setUpAll(initTestSupabase);

  late MockSocialRepository mockRepo;

  setUp(() {
    mockRepo = MockSocialRepository();
  });

  group('explorePostsProvider (PostFeedNotifier)', () {
    ProviderContainer buildContainer() => ProviderContainer(
      overrides: [
        fetchExplorePostsUseCaseProvider.overrideWithValue(
          FetchExplorePostsUseCase(mockRepo),
        ),
      ],
    );

    test(
      'loads the first page and sets hasMore when a full page comes back',
      () async {
        final page = _fullPage(startingAt: 0);
        when(
          () => mockRepo.fetchExplore(
            query: any(named: 'query'),
            before: any(named: 'before'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => Right(page));

        final container = buildContainer();
        addTearDown(container.dispose);
        container.listen(explorePostsProvider(null), (_, _) {});
        await Future<void>.delayed(Duration.zero);

        final state = container.read(explorePostsProvider(null));
        expect(state, isA<PostFeedLoaded>());
        expect((state as PostFeedLoaded).posts, page);
        expect(state.hasMore, isTrue);
      },
    );

    test(
      'hasMore is false when the first page is shorter than a full page',
      () async {
        when(
          () => mockRepo.fetchExplore(
            query: any(named: 'query'),
            before: any(named: 'before'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => Right([_post('post-1', DateTime.utc(2026))]));

        final container = buildContainer();
        addTearDown(container.dispose);
        container.listen(explorePostsProvider(null), (_, _) {});
        await Future<void>.delayed(Duration.zero);

        final state =
            container.read(explorePostsProvider(null)) as PostFeedLoaded;
        expect(state.hasMore, isFalse);
      },
    );

    test('loadMore appends the next page and requests it before the last '
        "loaded post's createdAt", () async {
      final firstPage = _fullPage(startingAt: 0);
      final secondPage = [_post('post-next', DateTime.utc(2025))];
      when(
        () => mockRepo.fetchExplore(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(firstPage));
      when(
        () => mockRepo.fetchExplore(
          query: any(named: 'query'),
          before: firstPage.last.createdAt,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(secondPage));

      final container = buildContainer();
      addTearDown(container.dispose);
      container.listen(explorePostsProvider(null), (_, _) {});
      await Future<void>.delayed(Duration.zero);

      await container.read(explorePostsProvider(null).notifier).loadMore();

      final state =
          container.read(explorePostsProvider(null)) as PostFeedLoaded;
      expect(state.posts, [...firstPage, ...secondPage]);
      expect(state.hasMore, isFalse); // secondPage is shorter than a full page
    });

    test(
      // SCALE-014 (docs/SCALABILITY_AUDIT.md): loadMore used to concatenate
      // every page forever. Loading enough pages to exceed
      // kMaxFeedWindowPosts (10 pages) must evict the earliest-loaded page
      // from the front while leaving the most recently loaded page intact
      // and the pagination cursor (.last) still correct.
      'loadMore evicts the oldest page once kMaxFeedWindowPosts is exceeded',
      () async {
        final pages = [
          for (var p = 0; p < 11; p++)
            _fullPage(startingAt: p * kSocialFeedPageSize),
        ];

        when(
          () => mockRepo.fetchExplore(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => Right(pages[0]));
        for (var p = 1; p < pages.length; p++) {
          when(
            () => mockRepo.fetchExplore(
              query: any(named: 'query'),
              before: pages[p - 1].last.createdAt,
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => Right(pages[p]));
        }

        final container = buildContainer();
        addTearDown(container.dispose);
        container.listen(explorePostsProvider(null), (_, _) {});
        await Future<void>.delayed(Duration.zero);

        for (var p = 1; p < pages.length; p++) {
          await container.read(explorePostsProvider(null).notifier).loadMore();
        }

        final state =
            container.read(explorePostsProvider(null)) as PostFeedLoaded;
        expect(state.posts.length, kMaxFeedWindowPosts);
        // page 0 (the very first, oldest-loaded page) was evicted...
        expect(
          state.posts.any((post) => post.id == pages[0].first.id),
          isFalse,
        );
        // ...but the most recently loaded page is still fully present.
        expect(
          state.posts.sublist(state.posts.length - kSocialFeedPageSize),
          pages.last,
        );
      },
    );

    test('loadMore is a no-op once hasMore is false', () async {
      when(
        () => mockRepo.fetchExplore(
          query: any(named: 'query'),
          before: any(named: 'before'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right([_post('post-1', DateTime.utc(2026))]));

      final container = buildContainer();
      addTearDown(container.dispose);
      container.listen(explorePostsProvider(null), (_, _) {});
      await Future<void>.delayed(Duration.zero);

      await container.read(explorePostsProvider(null).notifier).loadMore();

      // Only the initial fetchPage() call — loadMore() should have bailed
      // out immediately without calling the repository again.
      verify(
        () => mockRepo.fetchExplore(
          query: any(named: 'query'),
          before: any(named: 'before'),
          limit: any(named: 'limit'),
        ),
      ).called(1);
    });

    test(
      'refresh() re-fetches the first page in place, not a loading state',
      () async {
        final firstLoad = [_post('post-1', DateTime.utc(2026))];
        final afterRefresh = [_post('post-2', DateTime.utc(2026, 2))];
        var callCount = 0;
        when(
          () => mockRepo.fetchExplore(
            query: any(named: 'query'),
            before: any(named: 'before'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          return Right(callCount == 1 ? firstLoad : afterRefresh);
        });

        final container = buildContainer();
        addTearDown(container.dispose);
        container.listen(explorePostsProvider(null), (_, _) {});
        await Future<void>.delayed(Duration.zero);

        await container.read(explorePostsProvider(null).notifier).refresh();

        final state =
            container.read(explorePostsProvider(null)) as PostFeedLoaded;
        expect(state.posts, afterRefresh);
      },
    );
  });

  group('followingFeedProvider', () {
    test(
      'does not call the repository when signed out — empty Loaded state',
      () async {
        final container = ProviderContainer(
          overrides: [
            fetchFollowingFeedUseCaseProvider.overrideWithValue(
              FetchFollowingFeedUseCase(mockRepo),
            ),
            authNotifierProvider.overrideWith(
              (ref) => _buildAuthNotifier(null),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.listen(followingFeedProvider, (_, _) {});
        // Two async hops to settle: AuthNotifier's own getCurrentUser() call,
        // then followingFeedProvider rebuilding off that resolved auth state.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(followingFeedProvider);
        expect(state, isA<PostFeedLoaded>());
        expect((state as PostFeedLoaded).posts, isEmpty);
        verifyNever(
          () => mockRepo.fetchFeed(
            currentUserId: any(named: 'currentUserId'),
            before: any(named: 'before'),
            limit: any(named: 'limit'),
          ),
        );
      },
    );

    test('fetches with the signed-in user id when authenticated', () async {
      when(
        () => mockRepo.fetchFeed(
          currentUserId: any(named: 'currentUserId'),
          before: any(named: 'before'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const Right([]));

      final user = User(
        id: 'user-1',
        email: 'me@example.com',
        createdAt: DateTime(2026),
      );
      final container = ProviderContainer(
        overrides: [
          fetchFollowingFeedUseCaseProvider.overrideWithValue(
            FetchFollowingFeedUseCase(mockRepo),
          ),
          authNotifierProvider.overrideWith((ref) => _buildAuthNotifier(user)),
        ],
      );
      addTearDown(container.dispose);

      container.listen(followingFeedProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mockRepo.fetchFeed(
          currentUserId: 'user-1',
          limit: any(named: 'limit'),
        ),
      ).called(1);
    });
  });
}
