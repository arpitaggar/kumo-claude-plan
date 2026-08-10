import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/redeem_org_join_code_usecase.dart';
import 'package:kumo_claude/features/organization/presentation/pages/join_organization_page.dart';
import 'package:kumo_claude/features/organization/presentation/providers/organization_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;

  setUp(() {
    mockRepo = MockOrganizationRepository();
  });

  Future<void> pumpPage(WidgetTester tester, {String? initialCode}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          redeemOrgJoinCodeUseCaseProvider.overrideWithValue(
            RedeemOrgJoinCodeUseCase(mockRepo),
          ),
        ],
        child: MaterialApp(
          home: JoinOrganizationPage(initialCode: initialCode),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    // A deep-linked code (lib/config/router.dart's kumo://join?code=XYZ
    // redirect) arrives already known — showing the camera first would
    // just make the user switch views manually to see it prefilled.
    'with an initialCode, starts in manual-entry view with the field '
    'pre-filled instead of the scanner',
    (tester) async {
      await pumpPage(tester, initialCode: 'ABC123');

      expect(find.text('ABC123'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
    },
  );

  testWidgets('without an initialCode, starts in scanner view', (tester) async {
    await pumpPage(tester);

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('tapping Join redeems the pre-filled deep-link code', (
    tester,
  ) async {
    // A failure response is used deliberately so the success path's
    // `context.go(...)` never runs — this widget test has no GoRouter in
    // its tree (no other page test in this app sets one up either); what's
    // being verified is that the deep-linked code actually reaches the
    // usecase, not the post-success navigation.
    when(
      () => mockRepo.redeemJoinCode('ABC123'),
    ).thenAnswer((_) async => const Left(ServerFailure('nope')));

    await pumpPage(tester, initialCode: 'ABC123');
    await tester.tap(find.text('Join'));
    await tester.pump();

    verify(() => mockRepo.redeemJoinCode('ABC123')).called(1);
  });
}
