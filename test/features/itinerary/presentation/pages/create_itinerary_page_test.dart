import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/config/constants.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/create_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/presentation/pages/create_itinerary_page.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/itinerary_provider.dart';
import 'package:kumo_claude/features/itinerary/presentation/widgets/cost_field_picker.dart';
import 'package:kumo_claude/features/organization/domain/entities/organization.dart';
import 'package:kumo_claude/features/organization/presentation/providers/organization_provider.dart';
import 'package:kumo_claude/features/work_mode/presentation/providers/work_mode_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

class MockCreateItineraryUseCase extends Mock
    implements CreateItineraryUseCase {}

Organization _org(String id) => Organization(
  id: id,
  name: 'Acme Corp',
  slug: id,
  ownerId: 'owner-1',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

const _summary = ExpenseSummary(
  totalSpent: 0,
  spentByCategory: {},
  memberBalances: {},
);

TravelItinerary _createdTrip({String? orgId}) => TravelItinerary(
  id: 'new-trip',
  title: 'Test Trip',
  ownerId: 'user-1',
  startDate: DateTime.utc(2026, 6),
  endDate: DateTime.utc(2026, 6, 7),
  totalBudget: 500,
  currencyCode: AppConstants.defaultCurrency,
  members: const [],
  items: const [],
  expenseSummary: _summary,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  orgId: orgId,
);

Future<MockCreateItineraryUseCase> _pump(
  WidgetTester tester, {
  required bool workModeActive,
  Organization? workOrg,
}) async {
  final authRepo = MockAuthRepository();
  when(authRepo.getCurrentUser).thenAnswer(
    (_) async => Right(
      User(
        id: 'user-1',
        email: 'user-1@example.com',
        createdAt: DateTime.utc(2026),
      ),
    ),
  );
  final logoutUseCase = MockLogoutUseCase();
  when(logoutUseCase.call).thenAnswer((_) async => const Right(null));

  final createUseCase = MockCreateItineraryUseCase();
  when(
    () => createUseCase(
      title: any(named: 'title'),
      ownerId: any(named: 'ownerId'),
      ownerName: any(named: 'ownerName'),
      startDate: any(named: 'startDate'),
      endDate: any(named: 'endDate'),
      totalBudget: any(named: 'totalBudget'),
      currencyCode: any(named: 'currencyCode'),
      description: any(named: 'description'),
      items: any(named: 'items'),
      themeKey: any(named: 'themeKey'),
      orgId: any(named: 'orgId'),
    ),
  ).thenAnswer((_) async => Right(_createdTrip(orgId: workOrg?.id)));

  final overrides = <Override>[
    authNotifierProvider.overrideWith(
      (ref) => AuthNotifier(
        loginUseCase: MockLoginUseCase(),
        signupUseCase: MockSignupUseCase(),
        logoutUseCase: logoutUseCase,
        deleteAccountUseCase: MockDeleteAccountUseCase(),
        repository: authRepo,
      ),
    ),
    createItineraryUseCaseProvider.overrideWithValue(createUseCase),
    isWorkModeActiveProvider.overrideWithValue(workModeActive),
    currentWorkOrgProvider.overrideWithValue(workOrg),
  ];
  if (workOrg != null) {
    overrides.add(
      orgCostFieldsProvider(workOrg.id).overrideWith((ref) async => const []),
    );
  }

  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Pushed (not the initial location) so the page's context.pop() on a
  // successful submit has somewhere to go back to, matching real navigation
  // (Home/Trips push '/create-trip').
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
        path: '/create-trip',
        builder: (_, _) => const CreateItineraryPage(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        // Forces authNotifierProvider to build (and its async
        // _checkCurrentUser() to start resolving) as soon as the app mounts,
        // rather than only once CreateItineraryPage itself first reads it —
        // otherwise the initial AuthLoading -> AuthAuthenticated transition
        // can still be in flight by the time the test taps "Create Trip".
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
  router.push('/create-trip');
  await tester.pumpAndSettle();
  return createUseCase;
}

void main() {
  setUpAll(initTestSupabase);

  testWidgets('no org picker renders in Private Mode', (tester) async {
    await _pump(tester, workModeActive: false);

    expect(find.text('Organization (optional)'), findsNothing);
    expect(find.textContaining('will be tagged to'), findsNothing);
    expect(find.byType(CostFieldPicker), findsNothing);
  });

  testWidgets('no org picker renders in Work Mode either — tagging is '
      'automatic, not a choice', (tester) async {
    await _pump(tester, workModeActive: true, workOrg: _org('org-1'));

    expect(find.text('Organization (optional)'), findsNothing);
  });

  testWidgets('Work Mode shows the auto-tag notice and the cost field picker', (
    tester,
  ) async {
    await _pump(tester, workModeActive: true, workOrg: _org('org-1'));

    expect(find.text('This trip will be tagged to Acme Corp.'), findsOneWidget);
    final picker = tester.widget<CostFieldPicker>(find.byType(CostFieldPicker));
    expect(picker.orgId, 'org-1');
  });

  Future<void> fillRequiredFieldsAndSubmit(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Trip name'),
      'Test Trip',
    );

    final startField = find.ancestor(
      of: find.text('Start'),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(startField);
    await tester.tap(startField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final endField = find.ancestor(
      of: find.text('End'),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(endField);
    await tester.tap(endField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final amountField = find.widgetWithText(TextFormField, 'Amount');
    await tester.ensureVisible(amountField);
    await tester.enterText(amountField, '500');

    final createButton = find.widgetWithText(ElevatedButton, 'Create Trip');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();
  }

  testWidgets('submitting in Private Mode creates the trip with no orgId', (
    tester,
  ) async {
    final createUseCase = await _pump(tester, workModeActive: false);

    await fillRequiredFieldsAndSubmit(tester);

    final captured = verify(
      () => createUseCase(
        title: any(named: 'title'),
        ownerId: any(named: 'ownerId'),
        ownerName: any(named: 'ownerName'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        totalBudget: any(named: 'totalBudget'),
        currencyCode: any(named: 'currencyCode'),
        description: any(named: 'description'),
        items: any(named: 'items'),
        themeKey: any(named: 'themeKey'),
        orgId: captureAny(named: 'orgId'),
      ),
    ).captured;
    expect(captured.single, isNull);
  });

  testWidgets(
    'submitting in Work Mode auto-tags the trip with the current org',
    (tester) async {
      final org = _org('org-1');
      final createUseCase = await _pump(
        tester,
        workModeActive: true,
        workOrg: org,
      );

      await fillRequiredFieldsAndSubmit(tester);

      final captured = verify(
        () => createUseCase(
          title: any(named: 'title'),
          ownerId: any(named: 'ownerId'),
          ownerName: any(named: 'ownerName'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          totalBudget: any(named: 'totalBudget'),
          currencyCode: any(named: 'currencyCode'),
          description: any(named: 'description'),
          items: any(named: 'items'),
          themeKey: any(named: 'themeKey'),
          orgId: captureAny(named: 'orgId'),
        ),
      ).captured;
      expect(captured.single, 'org-1');
    },
  );
}
