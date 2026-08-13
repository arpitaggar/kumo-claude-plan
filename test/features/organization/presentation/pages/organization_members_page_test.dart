import 'dart:async';

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
import 'package:kumo_claude/features/organization/domain/entities/org_member.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/fetch_org_members_usecase.dart';
import 'package:kumo_claude/features/organization/domain/usecases/invite_org_member_usecase.dart';
import 'package:kumo_claude/features/organization/domain/usecases/remove_org_member_usecase.dart';
import 'package:kumo_claude/features/organization/domain/usecases/update_org_member_role_usecase.dart';
import 'package:kumo_claude/features/organization/presentation/pages/organization_members_page.dart';
import 'package:kumo_claude/features/organization/presentation/providers/organization_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

const _orgId = 'org-1';

OrgMember _member(
  String id, {
  required String userId,
  required String userName,
  required OrgMemberRole role,
}) => OrgMember(
  id: id,
  orgId: _orgId,
  userId: userId,
  userName: userName,
  role: role,
  joinedAt: DateTime.utc(2026),
);

final _me = _member(
  'm-1',
  userId: 'user-1',
  userName: 'Arpit',
  role: OrgMemberRole.owner,
);
final _bob = _member(
  'm-2',
  userId: 'user-2',
  userName: 'Bob',
  role: OrgMemberRole.member,
);
final _carol = _member(
  'm-3',
  userId: 'user-3',
  userName: 'Carol',
  role: OrgMemberRole.admin,
);

void main() {
  late MockOrganizationRepository mockOrgRepo;

  setUpAll(() async {
    registerFallbackValue(OrgMemberRole.member);
    await initTestSupabase();
  });

  setUp(() {
    mockOrgRepo = MockOrganizationRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final authRepo = MockAuthRepository();
    when(authRepo.getCurrentUser).thenAnswer(
      (_) async => Right(
        User(
          id: 'user-1',
          email: 'arpit@example.com',
          displayName: 'Arpit',
          createdAt: DateTime.utc(2026),
        ),
      ),
    );

    final router = GoRouter(
      initialLocation: '/organizations/$_orgId/members',
      routes: [
        GoRoute(
          path: '/organizations/:id/members',
          builder: (_, _) => const OrganizationMembersPage(orgId: _orgId),
        ),
        GoRoute(
          path: '/organizations/:id/approvals',
          builder: (_, _) => const Text('Approvals Page'),
        ),
        GoRoute(
          path: '/organizations/:id/cost-fields',
          builder: (_, _) => const Text('Cost Fields Page'),
        ),
        GoRoute(
          path: '/organizations/:id/join-codes',
          builder: (_, _) => const Text('Join Codes Page'),
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
          fetchOrgMembersUseCaseProvider.overrideWithValue(
            FetchOrgMembersUseCase(mockOrgRepo),
          ),
          inviteOrgMemberUseCaseProvider.overrideWithValue(
            InviteOrgMemberUseCase(mockOrgRepo),
          ),
          updateOrgMemberRoleUseCaseProvider.overrideWithValue(
            UpdateOrgMemberRoleUseCase(mockOrgRepo),
          ),
          removeOrgMemberUseCaseProvider.overrideWithValue(
            RemoveOrgMemberUseCase(mockOrgRepo),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  testWidgets('loading shows a spinner', (tester) async {
    when(
      () => mockOrgRepo.fetchOrgMembers(_orgId),
    ).thenAnswer((_) => Completer<Either<Failure, List<OrgMember>>>().future);

    await pumpPage(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error shows the failure message', (tester) async {
    when(
      () => mockOrgRepo.fetchOrgMembers(_orgId),
    ).thenAnswer((_) async => const Left(ServerFailure('boom')));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets(
    'renders one ListTile per member, owner has no manage menu, others do',
    (tester) async {
      when(
        () => mockOrgRepo.fetchOrgMembers(_orgId),
      ).thenAnswer((_) async => Right([_me, _bob, _carol]));

      await pumpPage(tester);
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.text('Arpit'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Carol'), findsOneWidget);
      // The signed-in user (owner) can manage the roster, but the owner
      // row itself is never given a manage menu (organization_members_page
      // .dart's `member.role != OrgMemberRole.owner` guard).
      expect(find.byType(PopupMenuButton<String>), findsNWidgets(2));
    },
  );

  testWidgets(
    "a member row's menu offers Make admin and Remove, not Make member",
    (tester) async {
      when(
        () => mockOrgRepo.fetchOrgMembers(_orgId),
      ).thenAnswer((_) async => Right([_me, _bob]));

      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Make admin'), findsOneWidget);
      expect(find.text('Make member'), findsNothing);
      expect(find.text('Remove'), findsOneWidget);
    },
  );

  testWidgets('selecting Make admin calls UpdateOrgMemberRoleUseCase', (
    tester,
  ) async {
    when(
      () => mockOrgRepo.fetchOrgMembers(_orgId),
    ).thenAnswer((_) async => Right([_me, _bob]));
    when(
      () => mockOrgRepo.updateMemberRole(
        orgMemberId: any(named: 'orgMemberId'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async => const Right(null));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make admin'));
    await tester.pumpAndSettle();

    verify(
      () => mockOrgRepo.updateMemberRole(
        orgMemberId: 'm-2',
        role: OrgMemberRole.admin,
      ),
    ).called(1);
  });

  testWidgets(
    'Remove asks for confirmation, and confirming calls RemoveOrgMemberUseCase',
    (tester) async {
      when(
        () => mockOrgRepo.fetchOrgMembers(_orgId),
      ).thenAnswer((_) async => Right([_me, _bob]));
      when(
        () => mockOrgRepo.removeMember('m-2'),
      ).thenAnswer((_) async => const Right(null));

      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Remove member?'), findsOneWidget);
      verifyNever(() => mockOrgRepo.removeMember(any()));

      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      verify(() => mockOrgRepo.removeMember('m-2')).called(1);
    },
  );

  testWidgets(
    'cancelling the remove-confirmation dialog never calls the usecase',
    (tester) async {
      when(
        () => mockOrgRepo.fetchOrgMembers(_orgId),
      ).thenAnswer((_) async => Right([_me, _bob]));

      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Remove member?'), findsNothing);
      verifyNever(() => mockOrgRepo.removeMember(any()));
    },
  );

  testWidgets(
    'Add member dialog: filling the email and tapping Add invites the '
    'member with the selected role',
    (tester) async {
      when(
        () => mockOrgRepo.fetchOrgMembers(_orgId),
      ).thenAnswer((_) async => Right([_me]));
      when(
        () => mockOrgRepo.inviteMember(
          orgId: any(named: 'orgId'),
          email: any(named: 'email'),
          role: any(named: 'role'),
        ),
      ).thenAnswer((_) async => Right(_bob));

      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_add_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bob@example.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      verify(
        () => mockOrgRepo.inviteMember(
          orgId: _orgId,
          email: 'bob@example.com',
          role: OrgMemberRole.member,
        ),
      ).called(1);
      expect(find.text('Member added'), findsOneWidget);
    },
  );

  testWidgets('cancelling the Add member dialog never calls the usecase', (
    tester,
  ) async {
    when(
      () => mockOrgRepo.fetchOrgMembers(_orgId),
    ).thenAnswer((_) async => Right([_me]));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(
      () => mockOrgRepo.inviteMember(
        orgId: any(named: 'orgId'),
        email: any(named: 'email'),
        role: any(named: 'role'),
      ),
    );
  });

  testWidgets('app-bar icons navigate to approvals/cost-fields/join-codes', (
    tester,
  ) async {
    when(
      () => mockOrgRepo.fetchOrgMembers(_orgId),
    ).thenAnswer((_) async => Right([_me]));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.approval_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Approvals Page'), findsOneWidget);
  });
}
