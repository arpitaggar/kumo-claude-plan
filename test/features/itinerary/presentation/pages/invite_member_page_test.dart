import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/config/constants.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/direct_messages/domain/repositories/direct_message_repository.dart';
import 'package:kumo_claude/features/direct_messages/presentation/providers/direct_message_provider.dart';
import 'package:kumo_claude/features/hitchhiker/presentation/providers/hitchhiker_provider.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/profile_result.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/create_pending_invitation_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/find_profile_by_email_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/search_profiles_by_name_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/update_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/presentation/pages/invite_member_page.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/itinerary_provider.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/profile_lookup_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockSearchProfilesByNameUseCase extends Mock
    implements SearchProfilesByNameUseCase {}

class MockFindProfileByEmailUseCase extends Mock
    implements FindProfileByEmailUseCase {}

class MockCreatePendingInvitationUseCase extends Mock
    implements CreatePendingInvitationUseCase {}

class MockUpdateItineraryUseCase extends Mock
    implements UpdateItineraryUseCase {}

class MockDirectMessageRepository extends Mock
    implements DirectMessageRepository {}

const _summary = ExpenseSummary(
  totalSpent: 0,
  spentByCategory: {},
  memberBalances: {},
);

TravelItinerary _trip() => TravelItinerary(
  id: 'trip-1',
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
);

const _profile = ProfileResult(
  id: 'user-2',
  displayName: 'Alex',
  email: 'alex@example.com',
  isSearchable: true,
);

class _Mocks {
  _Mocks({
    required this.searchUseCase,
    required this.findByEmailUseCase,
    required this.createPendingInvitationUseCase,
    required this.updateUseCase,
    required this.directMessageRepository,
  });

  final MockSearchProfilesByNameUseCase searchUseCase;
  final MockFindProfileByEmailUseCase findByEmailUseCase;
  final MockCreatePendingInvitationUseCase createPendingInvitationUseCase;
  final MockUpdateItineraryUseCase updateUseCase;
  final MockDirectMessageRepository directMessageRepository;
}

Future<_Mocks> _pump(
  WidgetTester tester, {
  TravelItinerary? itinerary,
  Either<Failure, List<ProfileResult>>? searchResult,
  Either<Failure, ProfileResult?>? findByEmailResult,
  Either<Failure, void>? pendingInvitationResult,
  Either<Failure, TravelItinerary>? updateResult,
}) async {
  final trip = itinerary ?? _trip();

  final searchUseCase = MockSearchProfilesByNameUseCase();
  when(
    () => searchUseCase.call(any(), excludeIds: any(named: 'excludeIds')),
  ).thenAnswer((_) async => searchResult ?? const Right([_profile]));

  final findByEmailUseCase = MockFindProfileByEmailUseCase();
  when(
    () => findByEmailUseCase.call(any()),
  ).thenAnswer((_) async => findByEmailResult ?? const Right(_profile));

  final createPendingInvitationUseCase = MockCreatePendingInvitationUseCase();
  when(
    () => createPendingInvitationUseCase.call(
      itineraryId: any(named: 'itineraryId'),
      invitedEmail: any(named: 'invitedEmail'),
      role: any(named: 'role'),
    ),
  ).thenAnswer((_) async => pendingInvitationResult ?? const Right(null));

  final updateUseCase = MockUpdateItineraryUseCase();
  when(
    () => updateUseCase(any()),
  ).thenAnswer((_) async => updateResult ?? Right(trip));

  final directMessageRepository = MockDirectMessageRepository();
  when(
    () => directMessageRepository.getOrCreateConversation(any()),
  ).thenAnswer((_) async => const Right('conv-1'));

  final overrides = <Override>[
    itineraryStreamProvider(trip.id).overrideWith((ref) => Stream.value(trip)),
    searchProfilesByNameUseCaseProvider.overrideWithValue(searchUseCase),
    findProfileByEmailUseCaseProvider.overrideWithValue(findByEmailUseCase),
    createPendingInvitationUseCaseProvider.overrideWithValue(
      createPendingInvitationUseCase,
    ),
    updateItineraryUseCaseProvider.overrideWithValue(updateUseCase),
    hitchhikersForTripProvider(trip.id).overrideWith((ref) async => const []),
    directMessageRepositoryProvider.overrideWithValue(directMessageRepository),
  ];

  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
        path: '/invite',
        builder: (_, _) => InviteMemberPage(itineraryId: trip.id),
      ),
      GoRoute(
        path: '/dm/:conversationId',
        builder: (_, state) => Scaffold(
          body: Text('DM thread ${state.pathParameters['conversationId']}'),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // ignore: unawaited_futures
  router.push('/invite');
  await tester.pumpAndSettle();

  return _Mocks(
    searchUseCase: searchUseCase,
    findByEmailUseCase: findByEmailUseCase,
    createPendingInvitationUseCase: createPendingInvitationUseCase,
    updateUseCase: updateUseCase,
    directMessageRepository: directMessageRepository,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_trip());
  });
  setUpAll(initTestSupabase);

  testWidgets('all 3 tabs render and switching between them works', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Search people'), findsOneWidget);
    expect(find.text('Invite by email'), findsOneWidget);
    expect(find.text('Add Hitchhiker'), findsOneWidget);
    // Search tab is the initial view.
    expect(find.text('Search by name…'), findsOneWidget);

    await tester.tap(find.text('Invite by email'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Email address'), findsOneWidget);

    await tester.tap(find.text('Add Hitchhiker'));
    await tester.pumpAndSettle();
    expect(find.text('Search by name…'), findsNothing);
  });

  testWidgets('search tab finds a discoverable profile and adds it to the '
      'trip on tap', (tester) async {
    final mocks = await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Al');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_add_outlined));
    await tester.pumpAndSettle();

    final captured = verify(() => mocks.updateUseCase(captureAny())).captured;
    final updated = captured.single as TravelItinerary;
    expect(updated.members, hasLength(1));
    expect(updated.members.single.userId, 'user-2');
  });

  testWidgets('search tab shows an empty-result message for no matches', (
    tester,
  ) async {
    await _pump(tester, searchResult: const Right([]));

    await tester.enterText(find.byType(TextField).first, 'Zz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.textContaining('No discoverable users found'), findsOneWidget);
  });

  testWidgets(
    'email tab: an existing account is found and can be added to the trip',
    (tester) async {
      final mocks = await _pump(tester);

      await tester.tap(find.text('Invite by email'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'alex@example.com',
      );
      await tester.tap(find.widgetWithIcon(FilledButton, Icons.search));
      await tester.pumpAndSettle();

      expect(find.text('alex@example.com'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'Add to Trip'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Add to Trip'));
      await tester.pumpAndSettle();

      final captured = verify(() => mocks.updateUseCase(captureAny())).captured;
      final updated = captured.single as TravelItinerary;
      expect(updated.members.single.userId, 'user-2');
    },
  );

  testWidgets(
    'email tab: an unregistered email falls back to a pending invite',
    (tester) async {
      final mocks = await _pump(tester, findByEmailResult: const Right(null));

      await tester.tap(find.text('Invite by email'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'nobody@example.com',
      );
      await tester.tap(find.widgetWithIcon(FilledButton, Icons.search));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No account found for nobody@example.com'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Send Invite'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Send Invite'));
      await tester.pumpAndSettle();

      verify(
        () => mocks.createPendingInvitationUseCase.call(
          itineraryId: 'trip-1',
          invitedEmail: 'nobody@example.com',
          role: 'viewer',
        ),
      ).called(1);
    },
  );

  testWidgets(
    'search tab: tapping Message resolves a conversation and navigates',
    (tester) async {
      final mocks = await _pump(tester);

      await tester.enterText(find.byType(TextField).first, 'Al');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();

      verify(
        () => mocks.directMessageRepository.getOrCreateConversation('user-2'),
      ).called(1);
      expect(find.text('DM thread conv-1'), findsOneWidget);
    },
  );

  testWidgets(
    'email tab: a found account shows a Message action alongside Add to '
    'Trip',
    (tester) async {
      final mocks = await _pump(tester);

      await tester.tap(find.text('Invite by email'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'alex@example.com',
      );
      await tester.tap(find.widgetWithIcon(FilledButton, Icons.search));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();

      verify(
        () => mocks.directMessageRepository.getOrCreateConversation('user-2'),
      ).called(1);
    },
  );

  testWidgets('email tab: the pending-invite (no account) case never shows a '
      'Message action', (tester) async {
    await _pump(tester, findByEmailResult: const Right(null));

    await tester.tap(find.text('Invite by email'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'nobody@example.com',
    );
    await tester.tap(find.widgetWithIcon(FilledButton, Icons.search));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No account found for nobody@example.com'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
  });
}
