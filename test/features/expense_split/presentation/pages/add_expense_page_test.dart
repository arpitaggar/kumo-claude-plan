import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/config/constants.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/expense_split/domain/entities/expense.dart';
import 'package:kumo_claude/features/expense_split/domain/usecases/add_expense_usecase.dart';
import 'package:kumo_claude/features/expense_split/presentation/pages/add_expense_page.dart';
import 'package:kumo_claude/features/expense_split/presentation/providers/expense_provider.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/itinerary_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockAddExpenseUseCase extends Mock implements AddExpenseUseCase {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

const _summary = ExpenseSummary(
  totalSpent: 0,
  spentByCategory: {},
  memberBalances: {},
);

TravelItinerary _trip({List<GroupMember> members = const []}) =>
    TravelItinerary(
      id: 'trip-1',
      title: 'Test Trip',
      ownerId: 'user-1',
      startDate: DateTime.utc(2026, 6),
      endDate: DateTime.utc(2026, 6, 7),
      totalBudget: 500,
      currencyCode: AppConstants.defaultCurrency,
      members: members,
      items: const [],
      expenseSummary: _summary,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

GroupMember _member(String id, String name) => GroupMember(
  userId: id,
  userName: name,
  role: GroupMemberRole.editor,
  joinedAt: DateTime.utc(2026),
);

Future<MockAddExpenseUseCase> _pump(
  WidgetTester tester, {
  required TravelItinerary itinerary,
  Either<Failure, Expense>? submitResult,
}) async {
  final addUseCase = MockAddExpenseUseCase();
  when(
    () => addUseCase(
      itineraryId: any(named: 'itineraryId'),
      title: any(named: 'title'),
      amount: any(named: 'amount'),
      currencyCode: any(named: 'currencyCode'),
      category: any(named: 'category'),
      payerId: any(named: 'payerId'),
      payerName: any(named: 'payerName'),
      splits: any(named: 'splits'),
      splitMode: any(named: 'splitMode'),
      exchangeRateToBase: any(named: 'exchangeRateToBase'),
      notes: any(named: 'notes'),
    ),
  ).thenAnswer(
    (_) async =>
        submitResult ??
        Right(
          Expense(
            id: 'expense-1',
            itineraryId: itinerary.id,
            title: 'Dinner',
            amount: 50,
            currencyCode: itinerary.currencyCode,
            category: ExpenseCategory.food,
            payerId: 'user-1',
            payerName: 'Me',
            splits: const [],
            createdAt: DateTime.utc(2026),
          ),
        ),
  );

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

  final overrides = <Override>[
    itineraryStreamProvider(
      itinerary.id,
    ).overrideWith((ref) => Stream.value(itinerary)),
    addExpenseUseCaseProvider.overrideWithValue(addUseCase),
    authNotifierProvider.overrideWith(
      (ref) => AuthNotifier(
        loginUseCase: MockLoginUseCase(),
        signupUseCase: MockSignupUseCase(),
        logoutUseCase: logoutUseCase,
        deleteAccountUseCase: MockDeleteAccountUseCase(),
        repository: authRepo,
      ),
    ),
  ];

  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
        path: '/add-expense',
        builder: (_, _) => AddExpensePage(itineraryId: itinerary.id),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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
  router.push('/add-expense');
  await tester.pumpAndSettle();
  return addUseCase;
}

void main() {
  setUpAll(() {
    registerFallbackValue(ExpenseCategory.other);
    registerFallbackValue(SplitMode.equal);
  });
  setUpAll(initTestSupabase);

  testWidgets('renders the form once the itinerary loads', (tester) async {
    await _pump(
      tester,
      itinerary: _trip(
        members: [_member('user-1', 'Me'), _member('user-2', 'Alex')],
      ),
    );

    expect(find.text('Add Expense'), findsWidgets);
    expect(
      find.widgetWithText(TextFormField, 'What was it for?'),
      findsOneWidget,
    );
    expect(find.text('Split equally among all 2 members'), findsOneWidget);
  });

  testWidgets('submit is blocked when the title is empty', (tester) async {
    final addUseCase = await _pump(
      tester,
      itinerary: _trip(members: [_member('user-1', 'Me')]),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '50');
    await tester.tap(find.widgetWithText(FilledButton, 'Add Expense'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsWidgets);
    verifyNever(
      () => addUseCase(
        itineraryId: any(named: 'itineraryId'),
        title: any(named: 'title'),
        amount: any(named: 'amount'),
        currencyCode: any(named: 'currencyCode'),
        category: any(named: 'category'),
        payerId: any(named: 'payerId'),
        payerName: any(named: 'payerName'),
        splits: any(named: 'splits'),
        splitMode: any(named: 'splitMode'),
        exchangeRateToBase: any(named: 'exchangeRateToBase'),
        notes: any(named: 'notes'),
      ),
    );
  });

  testWidgets(
    'submitting a valid equal-split expense calls AddExpenseUseCase with the right args',
    (tester) async {
      final addUseCase = await _pump(
        tester,
        itinerary: _trip(
          members: [_member('user-1', 'Me'), _member('user-2', 'Alex')],
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'What was it for?'),
        'Dinner',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '50',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add Expense'));
      await tester.pumpAndSettle();

      final captured = verify(
        () => addUseCase(
          itineraryId: 'trip-1',
          title: 'Dinner',
          amount: 50,
          currencyCode: AppConstants.defaultCurrency,
          category: ExpenseCategory.other,
          payerId: 'user-1',
          payerName: 'Me',
          splits: captureAny(named: 'splits'),
          notes: '',
        ),
      ).captured;
      final splits = captured.single as List<ExpenseSplit>;
      expect(splits, hasLength(1));
      expect(splits.single.userId, 'user-2');
      expect(splits.single.shareAmount, 25);
    },
  );

  testWidgets('shows a snackbar and stays on the page when the usecase fails', (
    tester,
  ) async {
    await _pump(
      tester,
      itinerary: _trip(
        members: [_member('user-1', 'Me'), _member('user-2', 'Alex')],
      ),
      submitResult: const Left(ServerFailure('Could not save expense')),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'What was it for?'),
      'Dinner',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '50');
    await tester.tap(find.widgetWithText(FilledButton, 'Add Expense'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save expense'), findsOneWidget);
    expect(find.text('Add Expense'), findsWidgets);
  });
}
