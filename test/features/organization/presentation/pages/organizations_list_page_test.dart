import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/organization.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/fetch_my_organizations_usecase.dart';
import 'package:kumo_claude/features/organization/presentation/pages/organizations_list_page.dart';
import 'package:kumo_claude/features/organization/presentation/providers/organization_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

Organization _org(String id, String name) => Organization(
  id: id,
  name: name,
  slug: '$id-slug',
  ownerId: 'user-1',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late MockOrganizationRepository mockRepo;

  setUp(() {
    mockRepo = MockOrganizationRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/organizations',
      routes: [
        GoRoute(
          path: '/organizations',
          builder: (_, _) => const OrganizationsListPage(),
        ),
        GoRoute(
          path: '/organizations/new',
          builder: (_, _) => const Text('New Organization Page'),
        ),
        GoRoute(
          path: '/organizations/join',
          builder: (_, _) => const Text('Join Organization Page'),
        ),
        GoRoute(
          path: '/organizations/:id/members',
          builder: (_, state) =>
              Text('Members of ${state.pathParameters['id']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fetchMyOrganizationsUseCaseProvider.overrideWithValue(
            FetchMyOrganizationsUseCase(mockRepo),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('loading shows a spinner', (tester) async {
    when(() => mockRepo.fetchMyOrganizations()).thenAnswer(
      (_) => Completer<Either<Failure, List<Organization>>>().future,
    );

    await pumpPage(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error shows the failure message', (tester) async {
    when(
      () => mockRepo.fetchMyOrganizations(),
    ).thenAnswer((_) async => const Left(ServerFailure('boom')));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('empty list shows the empty state with Create/Join actions', (
    tester,
  ) async {
    when(
      () => mockRepo.fetchMyOrganizations(),
    ).thenAnswer((_) async => const Right([]));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('You don\'t belong to any organization yet'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Create one'), findsOneWidget);
    expect(find.text('Have a join code?'), findsOneWidget);
  });

  testWidgets('with orgs, renders one ListTile per org and tapping one '
      'navigates to its members page', (tester) async {
    when(() => mockRepo.fetchMyOrganizations()).thenAnswer(
      (_) async => Right([_org('org-1', 'Acme Corp'), _org('org-2', 'Globex')]),
    );

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.text('Acme Corp'), findsOneWidget);
    expect(find.text('Globex'), findsOneWidget);

    await tester.tap(find.text('Acme Corp'));
    await tester.pumpAndSettle();

    expect(find.text('Members of org-1'), findsOneWidget);
  });

  testWidgets('tapping the app-bar add icon navigates to create-organization', (
    tester,
  ) async {
    when(
      () => mockRepo.fetchMyOrganizations(),
    ).thenAnswer((_) async => const Right([]));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('New Organization Page'), findsOneWidget);
  });

  testWidgets('tapping the app-bar join icon navigates to join-with-code', (
    tester,
  ) async {
    when(
      () => mockRepo.fetchMyOrganizations(),
    ).thenAnswer((_) async => const Right([]));

    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.qr_code_scanner_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Join Organization Page'), findsOneWidget);
  });
}
