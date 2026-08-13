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
import 'package:kumo_claude/features/chat/presentation/providers/chat_provider.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/fetch_itineraries_usecase.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/itinerary_provider.dart';
import 'package:kumo_claude/features/shell/inbox_page.dart';
import 'package:kumo_claude/features/work_mode/presentation/providers/work_mode_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_helpers.dart';

// Regression coverage for a real bug found 2026-08-13: InboxPage read
// itineraryListProvider's raw (unfiltered) list directly, instead of
// visibleItinerariesProvider like home_page.dart/trips_page.dart correctly
// do — so a personal account in Private Mode saw org-tagged trip chats too,
// and vice versa in Work Mode. This page had zero test coverage before this,
// which is exactly why nothing caught it when Work Mode shipped (Stage 22).

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

class MockFetchItinerariesUseCase extends Mock
    implements FetchItinerariesUseCase {}

const _summary = ExpenseSummary(
  totalSpent: 0,
  spentByCategory: {},
  memberBalances: {},
);

TravelItinerary _trip(String id, {String title = 'Trip', String? orgId}) =>
    TravelItinerary(
      id: id,
      title: title,
      ownerId: 'user-1',
      startDate: DateTime.utc(2026, 6),
      endDate: DateTime.utc(2026, 6, 7),
      totalBudget: 1000,
      currencyCode: 'USD',
      members: const [],
      items: const [],
      expenseSummary: _summary,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      orgId: orgId,
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<TravelItinerary> allTrips,
  required bool workModeActive,
}) async {
  final authRepo = MockAuthRepository();
  when(authRepo.getCurrentUser).thenAnswer(
    (_) async => Right(
      User(id: 'user-1', email: 'u@example.com', createdAt: DateTime.utc(2026)),
    ),
  );

  final fetchUseCase = MockFetchItinerariesUseCase();
  when(() => fetchUseCase('user-1')).thenAnswer((_) async => Right(allTrips));

  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, _) => const InboxPage())],
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
        fetchItinerariesUseCaseProvider.overrideWithValue(fetchUseCase),
        isWorkModeActiveProvider.overrideWithValue(workModeActive),
        for (final t in allTrips)
          chatStreamProvider(t.id).overrideWith((ref) => const Stream.empty()),
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
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(initTestSupabase);

  testWidgets(
    'Private Mode shows only personal (non-org) trip chats, not org-tagged '
    'ones',
    (tester) async {
      await _pump(
        tester,
        allTrips: [
          _trip('t1', title: 'Personal Trip'),
          _trip('t2', title: 'WorkTrip', orgId: 'org-1'),
        ],
        workModeActive: false,
      );

      expect(find.text('Personal Trip'), findsOneWidget);
      expect(find.text('WorkTrip'), findsNothing);
    },
  );

  testWidgets(
    'no trips visible in the current mode shows the empty state, not an '
    'unfiltered list',
    (tester) async {
      await _pump(
        tester,
        allTrips: [_trip('t2', title: 'WorkTrip', orgId: 'org-1')],
        workModeActive: false,
      );

      expect(find.text('No trip chats yet'), findsOneWidget);
      expect(find.text('WorkTrip'), findsNothing);
    },
  );

  testWidgets('shows every personal trip chat when there is no org trip '
      'mixed in', (tester) async {
    await _pump(
      tester,
      allTrips: [
        _trip('t1', title: 'Tokyo'),
        _trip('t3', title: 'Bali'),
      ],
      workModeActive: false,
    );

    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('Bali'), findsOneWidget);
  });
}
