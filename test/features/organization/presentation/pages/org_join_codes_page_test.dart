import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_cost_field.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_join_code.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_member.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/generate_org_join_code_usecase.dart';
import 'package:kumo_claude/features/organization/domain/usecases/revoke_org_join_code_usecase.dart';
import 'package:kumo_claude/features/organization/presentation/pages/org_join_codes_page.dart';
import 'package:kumo_claude/features/organization/presentation/providers/organization_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

const _orgId = 'org-1';

OrgJoinCode _code({
  String id = 'code-1',
  String code = 'ABC123',
  OrgMemberRole role = OrgMemberRole.member,
  int usesCount = 0,
  int? maxUses = 1,
  DateTime? revokedAt,
  DateTime? expiresAt,
}) => OrgJoinCode(
  id: id,
  orgId: _orgId,
  role: role,
  code: code,
  usesCount: usesCount,
  maxUses: maxUses,
  revokedAt: revokedAt,
  expiresAt: expiresAt,
  createdBy: 'admin-1',
  createdAt: DateTime.utc(2026),
);

void main() {
  late MockOrganizationRepository mockRepo;

  setUp(() {
    mockRepo = MockOrganizationRepository();
    registerFallbackValue(OrgMemberRole.member);
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    List<OrgJoinCode> codes = const [],
    List<OrgCostField> costFields = const [],
  }) async {
    final router = GoRouter(
      initialLocation: '/join-codes',
      routes: [
        GoRoute(
          path: '/join-codes',
          builder: (_, _) => const OrgJoinCodesPage(orgId: _orgId),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orgJoinCodesProvider(_orgId).overrideWith((ref) async => codes),
          orgCostFieldsProvider(_orgId).overrideWith((ref) async => costFields),
          generateOrgJoinCodeUseCaseProvider.overrideWithValue(
            GenerateOrgJoinCodeUseCase(mockRepo),
          ),
          revokeOrgJoinCodeUseCaseProvider.overrideWithValue(
            RevokeOrgJoinCodeUseCase(mockRepo),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty state renders when the org has no join codes yet', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.textContaining('No join codes yet'), findsOneWidget);
  });

  testWidgets('renders a code with its status, role, and use count', (
    tester,
  ) async {
    await pumpPage(tester, codes: [_code()]);

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.textContaining('Active'), findsOneWidget);
    expect(find.textContaining('0/1 uses'), findsOneWidget);
    expect(find.byIcon(Icons.block), findsOneWidget);
  });

  testWidgets('a revoked code shows no revoke action', (tester) async {
    await pumpPage(tester, codes: [_code(revokedAt: DateTime.utc(2026, 2))]);

    expect(find.textContaining('Revoked'), findsOneWidget);
    expect(find.byIcon(Icons.block), findsNothing);
  });

  testWidgets('generating a code calls the usecase and shows the result '
      'dialog on success', (tester) async {
    when(
      () => mockRepo.generateJoinCode(
        orgId: any(named: 'orgId'),
        role: any(named: 'role'),
        costFieldOptionId: any(named: 'costFieldOptionId'),
        expiresAt: any(named: 'expiresAt'),
        maxUses: any(named: 'maxUses'),
      ),
    ).thenAnswer((_) async => Right(_code(code: 'NEWCODE')));

    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    verify(
      () => mockRepo.generateJoinCode(
        orgId: _orgId,
        role: OrgMemberRole.member,
        expiresAt: any(named: 'expiresAt'),
        maxUses: 1,
      ),
    ).called(1);
    expect(find.text('NEWCODE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    // AlertDialog wraps its content in IntrinsicWidth, and QrImageView's
    // paint area is a bare LayoutBuilder — asking it for an intrinsic width
    // throws 'LayoutBuilder does not support returning intrinsic
    // dimensions' in debug builds (and silently renders at zero size in
    // release). A fixed-size SizedBox around QrImageView answers the
    // intrinsics query itself. This guards against a future refactor
    // "simplifying away" that wrapper, since without this test the crash is
    // otherwise invisible until someone actually taps Generate.
    'the generated-code QrImageView stays wrapped in a fixed-size SizedBox '
    "so AlertDialog's IntrinsicWidth pass never reaches it",
    (tester) async {
      when(
        () => mockRepo.generateJoinCode(
          orgId: any(named: 'orgId'),
          role: any(named: 'role'),
          costFieldOptionId: any(named: 'costFieldOptionId'),
          expiresAt: any(named: 'expiresAt'),
          maxUses: any(named: 'maxUses'),
        ),
      ).thenAnswer((_) async => Right(_code(code: 'NEWCODE')));

      await pumpPage(tester);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();

      final sizedBoxAboveQr = find.ancestor(
        of: find.byType(QrImageView),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 200 && w.height == 200,
        ),
      );
      expect(sizedBoxAboveQr, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failed generate shows the failure message, not a dialog', (
    tester,
  ) async {
    when(
      () => mockRepo.generateJoinCode(
        orgId: any(named: 'orgId'),
        role: any(named: 'role'),
        costFieldOptionId: any(named: 'costFieldOptionId'),
        expiresAt: any(named: 'expiresAt'),
        maxUses: any(named: 'maxUses'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('nope')));

    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    expect(find.text('nope'), findsOneWidget);
    expect(find.text('Join code'), findsNothing);
  });

  testWidgets('revoking a code confirms, then calls the usecase and '
      'refreshes the list', (tester) async {
    when(
      () => mockRepo.revokeJoinCode('code-1'),
    ).thenAnswer((_) async => const Right(null));

    await pumpPage(tester, codes: [_code()]);

    await tester.tap(find.byIcon(Icons.block));
    await tester.pumpAndSettle();
    expect(find.text('Revoke code?'), findsOneWidget);

    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();

    verify(() => mockRepo.revokeJoinCode('code-1')).called(1);
  });

  testWidgets('cancelling the revoke dialog never calls the usecase', (
    tester,
  ) async {
    await pumpPage(tester, codes: [_code()]);

    await tester.tap(find.byIcon(Icons.block));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => mockRepo.revokeJoinCode(any()));
  });
}
