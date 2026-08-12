import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/social/domain/entities/itinerary_post.dart';
import 'package:kumo_claude/features/social/domain/repositories/social_repository.dart';
import 'package:kumo_claude/features/social/presentation/pages/discover_page.dart';
import 'package:kumo_claude/features/social/presentation/providers/social_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

/// Signed-out `AuthNotifier` (real class, mocked repository underneath — see
/// social_provider_test.dart for why this can't just be a `Fake`
/// `StateNotifier`: `authNotifierProvider` is typed to the concrete
/// `AuthNotifier`). Signed-out keeps the "For You" tab (which `TabBarView`
/// builds immediately alongside Explore) trivially empty with no repository
/// calls, so these tests can focus on Explore's pagination without also
/// juggling an authenticated-feed fixture.
AuthNotifier _signedOutAuthNotifier() {
  final repo = MockAuthRepository();
  when(repo.getCurrentUser).thenAnswer((_) async => const Right(null));
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

  Future<void> pumpDiscoverPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          socialRepositoryProvider.overrideWithValue(mockRepo),
          authNotifierProvider.overrideWith((ref) => _signedOutAuthNotifier()),
        ],
        child: const MaterialApp(home: DiscoverPage()),
      ),
    );
    // Settles: AuthNotifier's getCurrentUser(), the following-feed rebuild
    // off that, and explorePostsProvider's own first fetch.
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows a post from the first page once loaded', (tester) async {
    when(
      () => mockRepo.fetchExplore(
        query: any(named: 'query'),
        before: any(named: 'before'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => Right([_post('hello', DateTime.utc(2026))]));

    await pumpDiscoverPage(tester);

    expect(find.text('Trip hello'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no public posts', (
    tester,
  ) async {
    when(
      () => mockRepo.fetchExplore(
        query: any(named: 'query'),
        before: any(named: 'before'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Right([]));

    await pumpDiscoverPage(tester);

    expect(find.text('No public trips yet'), findsOneWidget);
  });

  testWidgets('shows an error view with Retry when the fetch fails', (
    tester,
  ) async {
    when(
      () => mockRepo.fetchExplore(
        query: any(named: 'query'),
        before: any(named: 'before'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('offline')));

    await pumpDiscoverPage(tester);

    expect(find.text('ServerFailure: offline'), findsNothing); // sanity
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'shows "Load more" only when the first page is full, and tapping it '
    'appends the next page',
    (tester) async {
      final firstPage = _fullPage(startingAt: 0);
      final secondPage = [_post('post-next', DateTime.utc(2025))];
      when(
        () => mockRepo.fetchExplore(
          query: any(named: 'query'),
          before: null,
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

      await pumpDiscoverPage(tester);

      // 20 posts overflow the test viewport, so the trailing "Load more"
      // footer isn't built by the lazy ListView until scrolled into view.
      await tester.scrollUntilVisible(
        find.text('Load more'),
        300,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Load more'), findsOneWidget);
      expect(find.text('Trip post-next'), findsNothing);

      await tester.tap(find.text('Load more'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Trip post-next'),
        300,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Trip post-next'), findsOneWidget);
      // secondPage is shorter than a full page, so there's no next "Load
      // more" — it's gone once the last page is shown.
      expect(find.text('Load more'), findsNothing);
    },
  );

  testWidgets('typing a search term re-fetches Explore with that query', (
    tester,
  ) async {
    when(
      () => mockRepo.fetchExplore(
        query: any(named: 'query'),
        before: any(named: 'before'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Right([]));

    await pumpDiscoverPage(tester);

    await tester.enterText(find.byType(TextField), 'Tokyo');
    // _onSearch debounces 400ms before applying the query.
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    await tester.pump();

    verify(
      () => mockRepo.fetchExplore(
        query: 'Tokyo',
        before: any(named: 'before'),
        limit: any(named: 'limit'),
      ),
    ).called(1);
  });
}
