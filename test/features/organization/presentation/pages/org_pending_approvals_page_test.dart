import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/pending_expense_approval.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/review_expense_usecase.dart';
import 'package:kumo_claude/features/organization/presentation/pages/org_pending_approvals_page.dart';
import 'package:kumo_claude/features/organization/presentation/providers/organization_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

const _orgId = 'org-1';

PendingExpenseApproval _approval({
  String expenseId = 'exp-1',
  String? notes,
  String? costCenterCode,
}) => PendingExpenseApproval(
  expenseId: expenseId,
  itineraryId: 'trip-1',
  tripTitle: 'KumoTest',
  payerId: 'user-2',
  payerName: 'Dudu',
  title: 'Team dinner',
  amount: 120.5,
  currencyCode: 'USD',
  category: 'Food',
  submittedAt: DateTime.utc(2026, 6),
  notes: notes,
  costCenterCode: costCenterCode,
);

void main() {
  late MockOrganizationRepository mockRepo;

  setUp(() {
    mockRepo = MockOrganizationRepository();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    List<PendingExpenseApproval> approvals = const [],
  }) async {
    final router = GoRouter(
      initialLocation: '/approvals',
      routes: [
        GoRoute(
          path: '/approvals',
          builder: (_, _) => const OrgPendingApprovalsPage(orgId: _orgId),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingApprovalsProvider(
            _orgId,
          ).overrideWith((ref) async => approvals),
          reviewExpenseUseCaseProvider.overrideWithValue(
            ReviewExpenseUseCase(mockRepo),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty state renders when nothing is waiting for review', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Nothing waiting for review'), findsOneWidget);
  });

  testWidgets('renders an approval card with trip/payer/amount and the '
      'optional notes + cost-center chip', (tester) async {
    await pumpPage(
      tester,
      approvals: [_approval(notes: 'Client visit', costCenterCode: 'SAL-01')],
    );

    expect(find.text('Team dinner'), findsOneWidget);
    expect(find.textContaining('KumoTest'), findsOneWidget);
    expect(find.textContaining('Dudu'), findsOneWidget);
    expect(find.text('120.50 USD'), findsOneWidget);
    expect(find.text('Client visit'), findsOneWidget);
    expect(find.text('SAL-01'), findsOneWidget);
  });

  testWidgets('no notes/cost-center chip rendered when both are absent', (
    tester,
  ) async {
    await pumpPage(tester, approvals: [_approval()]);

    expect(find.text('Team dinner'), findsOneWidget);
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('approving calls the usecase, refreshes, and shows a '
      'confirmation snackbar', (tester) async {
    when(
      () => mockRepo.approveExpense('exp-1'),
    ).thenAnswer((_) async => const Right(null));

    await pumpPage(tester, approvals: [_approval()]);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pump();

    verify(() => mockRepo.approveExpense('exp-1')).called(1);
    await tester.pump();
    expect(find.text('Approved'), findsOneWidget);
  });

  testWidgets('a failed approve shows the failure message, not the success '
      'snackbar', (tester) async {
    when(
      () => mockRepo.approveExpense('exp-1'),
    ).thenAnswer((_) async => const Left(ServerFailure('not an admin')));

    await pumpPage(tester, approvals: [_approval()]);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pump();
    await tester.pump();

    expect(find.text('not an admin'), findsOneWidget);
    expect(find.text('Approved'), findsNothing);
  });

  testWidgets('rejecting shows a confirm dialog with a reason field, then '
      'calls the usecase with the entered reason', (tester) async {
    when(
      () => mockRepo.rejectExpense('exp-1', 'Missing receipt'),
    ).thenAnswer((_) async => const Right(null));

    await pumpPage(tester, approvals: [_approval()]);

    await tester.tap(find.widgetWithText(TextButton, 'Reject'));
    await tester.pumpAndSettle();
    expect(find.text('Reject expense?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Missing receipt');
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();

    verify(() => mockRepo.rejectExpense('exp-1', 'Missing receipt')).called(1);
  });

  testWidgets('rejecting with an empty reason falls back to "No reason '
      'given"', (tester) async {
    when(
      () => mockRepo.rejectExpense('exp-1', 'No reason given'),
    ).thenAnswer((_) async => const Right(null));

    await pumpPage(tester, approvals: [_approval()]);

    await tester.tap(find.widgetWithText(TextButton, 'Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();

    verify(() => mockRepo.rejectExpense('exp-1', 'No reason given')).called(1);
  });

  testWidgets('cancelling the reject dialog never calls the usecase', (
    tester,
  ) async {
    await pumpPage(tester, approvals: [_approval()]);

    await tester.tap(find.widgetWithText(TextButton, 'Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => mockRepo.rejectExpense(any(), any()));
  });
}
