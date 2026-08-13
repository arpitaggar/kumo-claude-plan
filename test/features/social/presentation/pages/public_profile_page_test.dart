import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/profile/domain/entities/user_profile.dart';
import 'package:kumo_claude/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:kumo_claude/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:kumo_claude/features/social/domain/entities/follow_stats.dart';
import 'package:kumo_claude/features/social/domain/entities/itinerary_post.dart';
import 'package:kumo_claude/features/social/domain/repositories/follow_repository.dart';
import 'package:kumo_claude/features/social/domain/repositories/social_repository.dart';
import 'package:kumo_claude/features/social/presentation/pages/public_profile_page.dart';
import 'package:kumo_claude/features/social/presentation/providers/social_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

class MockUserProfileRepository extends Mock implements UserProfileRepository {}

class MockSocialRepository extends Mock implements SocialRepository {}

class MockFollowRepository extends Mock implements FollowRepository {}

const _viewedUserId = 'viewed-user';
const _viewerUserId = 'viewer-user';

UserProfile _profile({
  bool private = false,
  String id = _viewedUserId,
  String displayName = 'Bob Traveller',
}) => UserProfile(
  id: id,
  email: 'bob@example.com',
  displayName: displayName,
  username: 'bob_t',
  bio: 'Loves mountains',
  isSearchable: true,
  profileVisibility: private ? 'private' : 'public',
  contactVisibility: 'collaborators_only',
  unitsPreference: 'metric',
  travelPreferenceTags: const [],
  updatedAt: DateTime.utc(2026),
);

ItineraryPost _post(String id, {String authorId = _viewedUserId}) =>
    ItineraryPost(
      id: id,
      authorId: authorId,
      authorName: 'Bob Traveller',
      title: 'Trip $id',
      startDate: DateTime.utc(2026, 6),
      endDate: DateTime.utc(2026, 6, 7),
      themeKey: 'classic',
      currencyCode: 'USD',
      items: const [],
      segments: const [],
      likeCount: 0,
      likedByMe: false,
      commentCount: 0,
      createdAt: DateTime.utc(2026, 6),
    );

AuthNotifier _authNotifier({String? signedInAs}) {
  final repo = MockAuthRepository();
  when(repo.getCurrentUser).thenAnswer(
    (_) async => Right(
      signedInAs == null
          ? null
          : User(
              id: signedInAs,
              email: 'viewer@example.com',
              createdAt: DateTime.utc(2026),
            ),
    ),
  );
  return AuthNotifier(
    loginUseCase: MockLoginUseCase(),
    signupUseCase: MockSignupUseCase(),
    logoutUseCase: MockLogoutUseCase(),
    deleteAccountUseCase: MockDeleteAccountUseCase(),
    repository: repo,
  );
}

Future<({MockSocialRepository socialRepo, MockFollowRepository followRepo})>
_pump(
  WidgetTester tester, {
  String? signedInAs = _viewerUserId,
  UserProfile? profile,
  List<ItineraryPost>? posts,
  FollowStats? followStats,
}) async {
  final socialRepo = MockSocialRepository();
  final followRepo = MockFollowRepository();
  final profileRepo = MockUserProfileRepository();

  when(
    () => profileRepo.getProfileById(any()),
  ).thenAnswer((_) async => Right(profile ?? _profile()));
  when(
    () => socialRepo.fetchPostsByAuthor(any()),
  ).thenAnswer((_) async => Right(posts ?? [_post('p1')]));
  when(
    () => followRepo.fetchFollowStats(
      userId: any(named: 'userId'),
      currentUserId: any(named: 'currentUserId'),
    ),
  ).thenAnswer(
    (_) async => Right(
      followStats ??
          const FollowStats(
            followerCount: 3,
            followingCount: 5,
            isFollowedByMe: false,
          ),
    ),
  );
  when(
    () => followRepo.toggleFollow(
      followerId: any(named: 'followerId'),
      followeeId: any(named: 'followeeId'),
      follow: any(named: 'follow'),
    ),
  ).thenAnswer((_) async => const Right(null));
  when(
    () => socialRepo.deletePost(any()),
  ).thenAnswer((_) async => const Right(null));

  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/u/$_viewedUserId',
    routes: [
      GoRoute(
        path: '/u/:id',
        builder: (_, _) => const PublicProfilePage(userId: _viewedUserId),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const SizedBox.shrink(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          (ref) => _authNotifier(signedInAs: signedInAs),
        ),
        userProfileRepositoryProvider.overrideWithValue(profileRepo),
        socialRepositoryProvider.overrideWithValue(socialRepo),
        followRepositoryProvider.overrideWithValue(followRepo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return (socialRepo: socialRepo, followRepo: followRepo);
}

void main() {
  setUpAll(initTestSupabase);

  testWidgets('renders display name, username, bio, and follow stats', (
    tester,
  ) async {
    await _pump(tester);

    // Appears twice: once in the profile header, once as the fixture
    // post's authorName in its PostCard.
    expect(find.text('Bob Traveller'), findsWidgets);
    expect(find.text('@bob_t'), findsOneWidget);
    expect(find.text('Loves mountains'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('shows a Follow button for another user\'s profile, not '
      'Edit Profile', (tester) async {
    await _pump(tester);

    expect(find.widgetWithText(FilledButton, 'Follow'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Edit Profile'), findsNothing);
  });

  testWidgets('shows Edit Profile, not Follow, when viewing your own '
      'profile', (tester) async {
    await _pump(tester, signedInAs: _viewedUserId);

    expect(find.widgetWithText(OutlinedButton, 'Edit Profile'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Follow'), findsNothing);
  });

  testWidgets('shows Unfollow when already followed by the viewer', (
    tester,
  ) async {
    await _pump(
      tester,
      followStats: const FollowStats(
        followerCount: 1,
        followingCount: 1,
        isFollowedByMe: true,
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Unfollow'), findsOneWidget);
  });

  testWidgets('tapping Follow calls toggleFollow with follow: true and '
      'the signed-in viewer as the follower', (tester) async {
    final ctx = await _pump(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Follow'));
    await tester.pumpAndSettle();

    verify(
      () => ctx.followRepo.toggleFollow(
        followerId: _viewerUserId,
        followeeId: _viewedUserId,
        follow: true,
      ),
    ).called(1);
  });

  testWidgets('shows a private-profile lock state and hides posts/bio '
      'when the viewed profile is private', (tester) async {
    await _pump(tester, profile: _profile(private: true));

    expect(find.text('This profile is private'), findsOneWidget);
    expect(find.text('Loves mountains'), findsNothing);
    expect(find.text('Trip p1'), findsNothing);
  });

  testWidgets('shows your own private profile\'s posts, since privacy '
      'gating only applies to other viewers', (tester) async {
    await _pump(
      tester,
      signedInAs: _viewedUserId,
      profile: _profile(private: true),
    );

    expect(find.text('This profile is private'), findsNothing);
    expect(find.text('Trip p1'), findsOneWidget);
  });

  testWidgets('shows the empty state when the author has no published '
      'trips', (tester) async {
    await _pump(tester, posts: []);

    expect(find.text('No published trips yet'), findsOneWidget);
  });

  testWidgets(
    'renders a post card for each published trip, newest content from '
    'fetchPostsByAuthor',
    (tester) async {
      await _pump(tester, posts: [_post('p1'), _post('p2')]);

      expect(find.text('Trip p1'), findsOneWidget);
      expect(find.text('Trip p2'), findsOneWidget);
    },
  );

  testWidgets('deleting a post on your own profile calls deletePost after '
      'confirmation', (tester) async {
    final ctx = await _pump(
      tester,
      signedInAs: _viewedUserId,
      posts: [_post('p1')],
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete this post?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();

    verify(() => ctx.socialRepo.deletePost('p1')).called(1);
  });
}
