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
import 'package:kumo_claude/features/home/presentation/pages/home_page.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/delete_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/fetch_itineraries_usecase.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/itinerary_provider.dart';
import 'package:kumo_claude/features/itinerary/presentation/widgets/itinerary_card.dart';
import 'package:kumo_claude/features/work_mode/presentation/providers/work_mode_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

// home_page.dart had zero test coverage before this — added 2026-08-13
// alongside the ItineraryCard delete-confirmation fix (see docs/Checklist.md)
// since this is the page that renders that card in production.

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

class MockFetchItinerariesUseCase extends Mock
    implements FetchItinerariesUseCase {}

class MockDeleteItineraryUseCase extends Mock
    implements DeleteItineraryUseCase {}

const _summary = ExpenseSummary(
  totalSpent: 0,
  spentByCategory: {},
  memberBalances: {},
);

TravelItinerary _trip(String id, {String title = 'Trip'}) => TravelItinerary(
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
);

Future<MockDeleteItineraryUseCase> _pump(
  WidgetTester tester, {
  required Either<Failure, List<TravelItinerary>> fetchResult,
}) async {
  final authRepo = MockAuthRepository();
  when(authRepo.getCurrentUser).thenAnswer(
    (_) async => Right(
      User(
        id: 'user-1',
        email: 'u@example.com',
        displayName: 'Arpit',
        createdAt: DateTime.utc(2026),
      ),
    ),
  );

  final fetchUseCase = MockFetchItinerariesUseCase();
  when(() => fetchUseCase('user-1')).thenAnswer((_) async => fetchResult);

  final deleteUseCase = MockDeleteItineraryUseCase();
  when(() => deleteUseCase(any())).thenAnswer((_) async => const Right(null));

  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, _) => const HomePage())],
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
        deleteItineraryUseCaseProvider.overrideWithValue(deleteUseCase),
        isWorkModeActiveProvider.overrideWithValue(false),
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
  await tester.pumpAndSettle();
  return deleteUseCase;
}

void main() {
  setUpAll(initTestSupabase);

  testWidgets('loaded with trips shows the greeting and a card per trip', (
    tester,
  ) async {
    await _pump(
      tester,
      fetchResult: Right([
        _trip('t1', title: 'Tokyo'),
        _trip('t2', title: 'Bali'),
      ]),
    );

    expect(find.textContaining('Arpit'), findsOneWidget);
    expect(find.text('My Trips'), findsOneWidget);
    expect(find.byType(ItineraryCard), findsNWidgets(2));
    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('Bali'), findsOneWidget);
  });

  testWidgets('empty list shows the "No trips yet" empty state', (
    tester,
  ) async {
    await _pump(tester, fetchResult: const Right([]));

    expect(find.text('No trips yet'), findsOneWidget);
    expect(find.text('Plan a Trip'), findsOneWidget);
    expect(find.byType(ItineraryCard), findsNothing);
  });

  testWidgets('fetch failure shows the error widget', (tester) async {
    await _pump(
      tester,
      fetchResult: const Left(ServerFailure('Something went wrong')),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('typing in search filters the trip list by title', (
    tester,
  ) async {
    await _pump(
      tester,
      fetchResult: Right([
        _trip('t1', title: 'Tokyo'),
        _trip('t2', title: 'Bali'),
      ]),
    );

    await tester.enterText(find.byType(TextField), 'tok');
    await tester.pumpAndSettle();

    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('Bali'), findsNothing);
    expect(find.text('Results'), findsOneWidget);
  });

  testWidgets('search with no matches shows the "No trips match" message', (
    tester,
  ) async {
    await _pump(tester, fetchResult: Right([_trip('t1', title: 'Tokyo')]));

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No trips match "zzz"'), findsOneWidget);
  });

  testWidgets(
    'confirming delete on a card calls DeleteItineraryUseCase and removes '
    'it from the list',
    (tester) async {
      final deleteUseCase = await _pump(
        tester,
        fetchResult: Right([_trip('t1', title: 'Tokyo')]),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      verify(() => deleteUseCase('t1')).called(1);
      expect(find.text('Tokyo'), findsNothing);
      expect(find.text('No trips yet'), findsOneWidget);
    },
  );
}
