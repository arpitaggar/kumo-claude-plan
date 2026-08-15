import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/profile/domain/entities/user_profile.dart';
import 'package:kumo_claude/features/profile/domain/repositories/avatar_repository.dart';
import 'package:kumo_claude/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:kumo_claude/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:kumo_claude/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

class MockUserProfileRepository extends Mock implements UserProfileRepository {}

class MockAvatarRepository extends Mock implements AvatarRepository {}

final _profile = UserProfile(
  id: 'user-1',
  email: 'alice@example.com',
  displayName: 'Alice Traveller',
  username: 'alice_t',
  isSearchable: true,
  profileVisibility: 'public',
  contactVisibility: 'collaborators_only',
  unitsPreference: 'metric',
  travelPreferenceTags: const ['hiking'],
  updatedAt: DateTime.utc(2026),
);

Future<
  ({
    MockAuthRepository authRepo,
    MockUserProfileRepository profileRepo,
    GoRouter router,
  })
>
_pump(WidgetTester tester, {UserProfile? profile}) async {
  final authRepo = MockAuthRepository();
  final profileRepo = MockUserProfileRepository();
  final avatarRepo = MockAvatarRepository();
  when(authRepo.getCurrentUser).thenAnswer(
    (_) async => Right(
      User(
        id: 'user-1',
        email: 'alice@example.com',
        createdAt: DateTime.utc(2026),
      ),
    ),
  );
  when(
    () => authRepo.updateProfile(
      displayName: any(named: 'displayName'),
      avatarUrl: any(named: 'avatarUrl'),
    ),
  ).thenAnswer(
    (_) async => Right(
      User(
        id: 'user-1',
        email: 'alice@example.com',
        createdAt: DateTime.utc(2026),
      ),
    ),
  );
  when(
    () => profileRepo.updateProfile(
      displayName: any(named: 'displayName'),
      username: any(named: 'username'),
      bio: any(named: 'bio'),
      city: any(named: 'city'),
      country: any(named: 'country'),
      timezone: any(named: 'timezone'),
      preferredCurrency: any(named: 'preferredCurrency'),
      preferredLanguage: any(named: 'preferredLanguage'),
      unitsPreference: any(named: 'unitsPreference'),
      travelPreferenceTags: any(named: 'travelPreferenceTags'),
      profileVisibility: any(named: 'profileVisibility'),
      contactVisibility: any(named: 'contactVisibility'),
      avatarUrl: any(named: 'avatarUrl'),
      pushMessagePreviewEnabled: any(named: 'pushMessagePreviewEnabled'),
      enabledAccommodationSources: any(named: 'enabledAccommodationSources'),
    ),
  ).thenAnswer((_) async => Right(profile ?? _profile));

  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
        path: '/edit-profile',
        builder: (_, _) => const EditProfilePage(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          (ref) => AuthNotifier(
            loginUseCase: MockLoginUseCase(),
            signupUseCase: MockSignupUseCase(),
            logoutUseCase: MockLogoutUseCase(),
            deleteAccountUseCase: MockDeleteAccountUseCase(),
            repository: authRepo,
          ),
        ),
        userProfileProvider.overrideWith((ref) async => profile ?? _profile),
        userProfileRepositoryProvider.overrideWithValue(profileRepo),
        avatarRepositoryProvider.overrideWithValue(avatarRepo),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => Consumer(
          builder: (context, ref, _) {
            ref.watch(authNotifierProvider);
            return child!;
          },
        ),
      ),
    ),
  );
  // ignore: unawaited_futures
  router.push('/edit-profile');
  await tester.pumpAndSettle();

  return (authRepo: authRepo, profileRepo: profileRepo, router: router);
}

void main() {
  setUpAll(initTestSupabase);

  testWidgets('pre-fills fields from the loaded profile', (tester) async {
    await _pump(tester);

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Alice Traveller'), findsOneWidget);
    expect(find.text('alice_t'), findsOneWidget);
  });

  testWidgets('shows a validation error when Display Name is cleared', (
    tester,
  ) async {
    final ctx = await _pump(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), '');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Display name cannot be empty'), findsOneWidget);
    verifyNever(
      () => ctx.profileRepo.updateProfile(
        displayName: any(named: 'displayName'),
        username: any(named: 'username'),
        bio: any(named: 'bio'),
        city: any(named: 'city'),
        country: any(named: 'country'),
        timezone: any(named: 'timezone'),
        preferredCurrency: any(named: 'preferredCurrency'),
        preferredLanguage: any(named: 'preferredLanguage'),
        unitsPreference: any(named: 'unitsPreference'),
        travelPreferenceTags: any(named: 'travelPreferenceTags'),
        profileVisibility: any(named: 'profileVisibility'),
        contactVisibility: any(named: 'contactVisibility'),
        avatarUrl: any(named: 'avatarUrl'),
        pushMessagePreviewEnabled: any(named: 'pushMessagePreviewEnabled'),
        enabledAccommodationSources: any(named: 'enabledAccommodationSources'),
      ),
    );
  });

  testWidgets(
    'saving with a valid form updates both auth metadata and the profile '
    'row, then pops with a confirmation snackbar',
    (tester) async {
      final ctx = await _pump(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your name'),
        'Alice Updated',
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pump(); // completes the awaited authRepo.updateProfile
      await tester.pump(); // completes the awaited profileRepo.updateProfile
      await tester.pump(); // builds the frame showing the snackbar + pop

      verify(
        () => ctx.authRepo.updateProfile(
          displayName: 'Alice Updated',
          avatarUrl: any(named: 'avatarUrl'),
        ),
      ).called(1);
      verify(
        () => ctx.profileRepo.updateProfile(
          displayName: 'Alice Updated',
          username: any(named: 'username'),
          bio: any(named: 'bio'),
          city: any(named: 'city'),
          country: any(named: 'country'),
          timezone: any(named: 'timezone'),
          preferredCurrency: any(named: 'preferredCurrency'),
          preferredLanguage: any(named: 'preferredLanguage'),
          unitsPreference: any(named: 'unitsPreference'),
          travelPreferenceTags: any(named: 'travelPreferenceTags'),
          profileVisibility: any(named: 'profileVisibility'),
          contactVisibility: any(named: 'contactVisibility'),
          avatarUrl: any(named: 'avatarUrl'),
          pushMessagePreviewEnabled: any(named: 'pushMessagePreviewEnabled'),
          enabledAccommodationSources: any(
            named: 'enabledAccommodationSources',
          ),
        ),
      ).called(1);
      // Checked before pumpAndSettle — a real SnackBar's dismiss timer keeps
      // firing on the test's fake clock and pumpAndSettle would run past it.
      expect(find.text('Profile updated'), findsOneWidget);

      await tester.pumpAndSettle();
      // Popped back to the placeholder route.
      expect(find.byType(EditProfilePage), findsNothing);
    },
  );

  testWidgets('shows a snackbar and stays on the page when the profile '
      'update fails', (tester) async {
    final ctx = await _pump(tester);
    when(
      () => ctx.profileRepo.updateProfile(
        displayName: any(named: 'displayName'),
        username: any(named: 'username'),
        bio: any(named: 'bio'),
        city: any(named: 'city'),
        country: any(named: 'country'),
        timezone: any(named: 'timezone'),
        preferredCurrency: any(named: 'preferredCurrency'),
        preferredLanguage: any(named: 'preferredLanguage'),
        unitsPreference: any(named: 'unitsPreference'),
        travelPreferenceTags: any(named: 'travelPreferenceTags'),
        profileVisibility: any(named: 'profileVisibility'),
        contactVisibility: any(named: 'contactVisibility'),
        avatarUrl: any(named: 'avatarUrl'),
        pushMessagePreviewEnabled: any(named: 'pushMessagePreviewEnabled'),
        enabledAccommodationSources: any(named: 'enabledAccommodationSources'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('Update failed')));

    await tester.tap(find.text('Save Changes'));
    await tester.pump(); // completes the awaited authRepo.updateProfile
    await tester.pump(); // completes the awaited profileRepo.updateProfile
    await tester.pump(); // builds the frame showing the snackbar

    expect(find.text('Update failed'), findsOneWidget);
    expect(find.byType(EditProfilePage), findsOneWidget);
  });

  testWidgets('toggling a travel-interest chip updates its selected state', (
    tester,
  ) async {
    await _pump(tester);

    // 'hiking' starts selected (from the fixture profile); 'beach' doesn't.
    final beachChip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'beach'),
    );
    expect(beachChip.selected, isFalse);

    await tester.tap(find.text('beach'));
    await tester.pumpAndSettle();

    final beachChipAfter = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'beach'),
    );
    expect(beachChipAfter.selected, isTrue);
  });

  testWidgets(
    'every accommodation source starts selected when the profile has never '
    'customized this (enabledAccommodationSources is null, meaning "all")',
    (tester) async {
      await _pump(tester);

      final airbnbChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Airbnb'),
      );
      final bookingChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Booking.com'),
      );
      expect(airbnbChip.selected, isTrue);
      expect(bookingChip.selected, isTrue);
    },
  );

  testWidgets('toggling an accommodation source chip updates its selected '
      'state', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Airbnb'));
    await tester.pumpAndSettle();

    final airbnbChipAfter = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Airbnb'),
    );
    expect(airbnbChipAfter.selected, isFalse);
  });
}
