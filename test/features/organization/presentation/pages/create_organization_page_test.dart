import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/organization.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/create_organization_usecase.dart';
import 'package:kumo_claude/features/organization/presentation/pages/create_organization_page.dart';
import 'package:kumo_claude/features/organization/presentation/providers/organization_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

Organization _org({String id = 'org-1', String name = 'Acme Corp'}) =>
    Organization(
      id: id,
      name: name,
      slug: 'acme-corp-abc',
      ownerId: 'user-1',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  late MockOrganizationRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(_org());
  });

  setUp(() {
    mockRepo = MockOrganizationRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    // Reached by a `context.push` in production (from
    // organizations_list_page.dart), so the router needs a prior stack
    // entry for `pop()` inside `_submit`'s success branch to have anywhere
    // to go back to.
    final router = GoRouter(
      initialLocation: '/organizations',
      routes: [
        GoRoute(path: '/organizations', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/organizations/new',
          builder: (_, _) => const CreateOrganizationPage(),
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
          createOrganizationUseCaseProvider.overrideWithValue(
            CreateOrganizationUseCase(mockRepo),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    // Not awaited — this future only completes when the page is later
    // popped, which some tests never do.
    unawaited(router.push('/organizations/new'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the name field and Create button', (tester) async {
    await pumpPage(tester);

    expect(find.text('New Organization'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create'), findsOneWidget);
  });

  testWidgets('submitting with an empty name shows a validation error and '
      'never calls the usecase', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pump();

    expect(find.text('Name is required'), findsOneWidget);
    verifyNever(
      () => mockRepo.createOrganization(
        name: any(named: 'name'),
        slug: any(named: 'slug'),
      ),
    );
  });

  testWidgets(
    'successful submit creates the org, shows a snackbar, and navigates to '
    'its members page',
    (tester) async {
      when(
        () => mockRepo.createOrganization(
          name: any(named: 'name'),
          slug: any(named: 'slug'),
        ),
      ).thenAnswer((_) async => Right(_org(id: 'new-org')));

      await pumpPage(tester);
      await tester.enterText(find.byType(TextFormField), 'Acme Corp');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pump(); // completes the awaited createOrganization call
      await tester.pump(); // builds the frame showing the snackbar + new route

      verify(
        () => mockRepo.createOrganization(
          name: 'Acme Corp',
          slug: any(named: 'slug'),
        ),
      ).called(1);
      // Checked before pumpAndSettle — a real SnackBar's dismiss timer keeps
      // firing on the test's fake clock and pumpAndSettle would run past it.
      expect(find.text('Acme Corp created'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Members of new-org'), findsOneWidget);
    },
  );

  testWidgets('failed submit shows the failure message and stays on the '
      'form', (tester) async {
    when(
      () => mockRepo.createOrganization(
        name: any(named: 'name'),
        slug: any(named: 'slug'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('Name already taken')));

    await pumpPage(tester);
    await tester.enterText(find.byType(TextFormField), 'Acme Corp');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Name already taken'), findsOneWidget);
    expect(find.text('New Organization'), findsOneWidget);
  });
}
