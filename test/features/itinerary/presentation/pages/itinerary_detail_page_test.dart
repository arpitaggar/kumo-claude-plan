import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/config/constants.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/core/geocoding/geocoding_providers.dart';
import 'package:kumo_claude/core/geocoding/geocoding_service.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/direct_messages/domain/repositories/direct_message_repository.dart';
import 'package:kumo_claude/features/direct_messages/presentation/providers/direct_message_provider.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/presentation/pages/itinerary_detail_page.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/itinerary_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

// itinerary_detail_page.dart previously had zero test coverage. These tests
// lock in two real rendering crashes found by driving the live web build
// against production data (2026-08-13): (1) the Start/End/Duration overview
// pills overflowed a RenderFlex at phone-width viewports because they used
// their natural (unshrinkable) size instead of sharing the row's width, and
// (2) the Publish/"Publish update" button threw "BoxConstraints forces an
// infinite width" under the web (CanvasKit) renderer specifically — not
// reproducible under flutter test's default renderer, only caught by
// actually running the app. Both were real, not flutter-test artifacts:
// bug (1) reproduces here; bug (2) was verified against the running web
// build (see docs/Checklist.md), since this test harness's renderer never
// hit it even before the fix. Fixed by wrapping each _InfoPill in Expanded
// (with ellipsis-safe text) and the Publish/Publish-update button in
// Flexible, so a fresh regression here plus a manual web smoke-test after
// any further change to this row is the recommended combination.

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

class MockDirectMessageRepository extends Mock
    implements DirectMessageRepository {}

const _summary = ExpenseSummary(
  totalSpent: 0,
  spentByCategory: {},
  memberBalances: {},
);

TravelItinerary _trip({
  required bool isPublic,
  String ownerId = 'user-1',
  ItineraryStatusEnum status = ItineraryStatusEnum.draft,
  List<GroupMember> members = const [],
  List<String> accommodationSources = const [],
}) => TravelItinerary(
  id: 'trip-1',
  title: 'KumoTest',
  ownerId: ownerId,
  startDate: DateTime.utc(2026, 6, 8),
  endDate: DateTime.utc(2026, 6, 15),
  totalBudget: 9000,
  currencyCode: AppConstants.defaultCurrency,
  members: members,
  items: const [],
  expenseSummary: _summary,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  isPublic: isPublic,
  status: status,
  accommodationSources: accommodationSources,
);

/// Fixed single-result stand-in for the real (network-hitting) geocoding
/// service — the Stay tab geocodes the trip title to a search center (see
/// itinerary_detail_page.dart's `_accommodationSearchCenterProvider`), and
/// nothing in this file should make a real HTTP call.
class _FakeGeocodingService implements GeocodingService {
  @override
  Future<List<GeocodingResult>> search(String query) async => const [
    GeocodingResult(
      name: 'Verona, Italy',
      latitude: 45.4384,
      longitude: 10.9916,
    ),
  ];
}

/// Simulates a trip title that doesn't resolve to any real place.
class _EmptyGeocodingService implements GeocodingService {
  @override
  Future<List<GeocodingResult>> search(String query) async => const [];
}

/// An editor-role membership for 'user-1' — canEdit in the real page
/// requires the current user to actually appear in `members` with a
/// non-viewer role, which the bare `_trip()` fixture above deliberately
/// doesn't include (existing tests don't need edit-gated UI).
final _editorMember = GroupMember(
  userId: 'user-1',
  userName: 'Arpit',
  role: GroupMemberRole.editor,
  joinedAt: DateTime.utc(2026),
);

Future<void> _pump(
  WidgetTester tester, {
  required bool isPublic,
  String ownerId = 'user-1',
  ItineraryStatusEnum status = ItineraryStatusEnum.draft,
  List<GroupMember> members = const [],
  List<String> accommodationSources = const [],
  GeocodingService? geocodingService,
  DirectMessageRepository? directMessageRepository,
}) async {
  final authRepo = MockAuthRepository();
  when(authRepo.getCurrentUser).thenAnswer(
    (_) async => Right(
      User(id: 'user-1', email: 'u@example.com', createdAt: DateTime.utc(2026)),
    ),
  );

  // Phone-width viewport — the overview-pill overflow only reproduces at
  // narrow widths, not the wide default flutter_test surface.
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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
        itineraryStreamProvider('trip-1').overrideWith(
          (ref) => Stream.value(
            _trip(
              isPublic: isPublic,
              ownerId: ownerId,
              status: status,
              members: members,
              accommodationSources: accommodationSources,
            ),
          ),
        ),
        if (geocodingService != null)
          geocodingServiceProvider.overrideWithValue(geocodingService),
        if (directMessageRepository != null)
          directMessageRepositoryProvider.overrideWithValue(
            directMessageRepository,
          ),
      ],
      child: const MaterialApp(home: ItineraryDetailPage(id: 'trip-1')),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(initTestSupabase);

  testWidgets(
    'owner viewing an unpublished draft trip renders the Itinerary tab '
    'without a layout exception',
    (tester) async {
      await _pump(tester, isPublic: false);

      expect(tester.takeException(), isNull);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Not published'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Publish'), findsOneWidget);
    },
  );

  testWidgets(
    'owner viewing an already-published trip renders the Itinerary tab '
    'without a layout exception',
    (tester) async {
      await _pump(tester, isPublic: true);

      expect(tester.takeException(), isNull);
      expect(find.text('Published to Discover'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Publish update'), findsOneWidget);
    },
  );

  testWidgets(
    'non-owner viewing the trip renders without a layout exception and '
    'never shows the owner-only Status/Publish controls',
    (tester) async {
      await _pump(tester, isPublic: false, ownerId: 'someone-else');

      expect(tester.takeException(), isNull);
      expect(find.text('Start'), findsOneWidget);
      // The Status row itself is unconditional; only the owner-only
      // publish-status row (below the Divider) is gated on _isOwner.
      expect(find.text('Not published'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    },
  );

  testWidgets(
    'the Publish button stays wrapped in Flexible — required specifically '
    'under the web/CanvasKit renderer, not reproducible in this test suite '
    '(see the comment on this Row in itinerary_detail_page.dart)',
    (tester) async {
      await _pump(tester, isPublic: false);

      final publishButton = find.widgetWithText(FilledButton, 'Publish');
      expect(
        find.ancestor(of: publishButton, matching: find.byType(Flexible)),
        findsOneWidget,
      );
    },
  );

  group('editable dates (draft mode)', () {
    testWidgets(
      'an editor on a draft trip can tap Start to open the date picker',
      (tester) async {
        await _pump(tester, isPublic: false, members: [_editorMember]);

        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();

        expect(find.byType(DatePickerDialog), findsOneWidget);
      },
    );

    testWidgets('an editor on a draft trip can tap End to open the date '
        'picker', (tester) async {
      await _pump(tester, isPublic: false, members: [_editorMember]);

      await tester.tap(find.text('End'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets(
      'dates are not tappable once the trip is no longer a draft, even '
      'for an editor',
      (tester) async {
        await _pump(
          tester,
          isPublic: false,
          status: ItineraryStatusEnum.active,
          members: [_editorMember],
        );

        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();

        expect(find.byType(DatePickerDialog), findsNothing);
      },
    );

    testWidgets(
      'dates are not tappable for a viewer-role member, even in draft',
      (tester) async {
        await _pump(
          tester,
          isPublic: false,
          members: [
            GroupMember(
              userId: 'user-1',
              userName: 'Arpit',
              role: GroupMemberRole.viewer,
              joinedAt: DateTime.utc(2026),
            ),
          ],
        );

        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();

        expect(find.byType(DatePickerDialog), findsNothing);
      },
    );
  });

  group('editable theme', () {
    testWidgets('an editor sees a "Change theme" action in the app bar', (
      tester,
    ) async {
      await _pump(tester, isPublic: false, members: [_editorMember]);

      expect(find.byTooltip('Change theme'), findsOneWidget);
    });

    testWidgets(
      'the theme action is available even once the trip is no longer a '
      'draft — unlike dates, theme is cosmetic and safe to change any time',
      (tester) async {
        await _pump(
          tester,
          isPublic: false,
          status: ItineraryStatusEnum.active,
          members: [_editorMember],
        );

        expect(find.byTooltip('Change theme'), findsOneWidget);
      },
    );

    testWidgets('a non-owner/non-member never sees the theme action', (
      tester,
    ) async {
      await _pump(tester, isPublic: false, ownerId: 'someone-else');

      expect(find.byTooltip('Change theme'), findsNothing);
    });

    testWidgets('tapping "Change theme" opens the theme picker sheet', (
      tester,
    ) async {
      await _pump(tester, isPublic: false, members: [_editorMember]);

      await tester.tap(find.byTooltip('Change theme'));
      await tester.pumpAndSettle();

      expect(find.text('Trip Theme'), findsOneWidget);
    });
  });

  group('accommodation sources', () {
    testWidgets(
      'an editor sees an "Accommodation sources" action in the app bar',
      (tester) async {
        await _pump(tester, isPublic: false, members: [_editorMember]);

        expect(find.byTooltip('Accommodation sources'), findsOneWidget);
      },
    );

    testWidgets('a non-owner/non-member never sees the action', (tester) async {
      await _pump(tester, isPublic: false, ownerId: 'someone-else');

      expect(find.byTooltip('Accommodation sources'), findsNothing);
    });

    testWidgets(
      'tapping the action opens a sheet seeded with the trip\'s current '
      'sources',
      (tester) async {
        await _pump(
          tester,
          isPublic: false,
          members: [_editorMember],
          accommodationSources: const ['airbnb'],
        );

        await tester.tap(find.byTooltip('Accommodation sources'));
        await tester.pumpAndSettle();

        expect(find.text('Accommodation Sources'), findsOneWidget);
        final airbnbChip = tester.widget<FilterChip>(
          find.ancestor(
            of: find.text('Airbnb'),
            matching: find.byType(FilterChip),
          ),
        );
        final expediaChip = tester.widget<FilterChip>(
          find.ancestor(
            of: find.text('Expedia'),
            matching: find.byType(FilterChip),
          ),
        );
        expect(airbnbChip.selected, isTrue);
        expect(expediaChip.selected, isFalse);
      },
    );

    testWidgets('toggling a chip in the sheet updates its selected state', (
      tester,
    ) async {
      await _pump(tester, isPublic: false, members: [_editorMember]);

      await tester.tap(find.byTooltip('Accommodation sources'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(
              find.ancestor(
                of: find.text('Booking.com'),
                matching: find.byType(FilterChip),
              ),
            )
            .selected,
        isFalse,
      );

      await tester.tap(find.text('Booking.com'));
      await tester.pump();

      expect(
        tester
            .widget<FilterChip>(
              find.ancestor(
                of: find.text('Booking.com'),
                matching: find.byType(FilterChip),
              ),
            )
            .selected,
        isTrue,
      );
    });
  });

  group('Stay tab', () {
    testWidgets('renders the source/price/radius filters once the destination '
        'resolves, without a layout exception', (tester) async {
      await _pump(
        tester,
        isPublic: false,
        members: [_editorMember],
        accommodationSources: const [
          'airbnb',
          'expedia',
          'booking',
          'hostelworld',
        ],
        geocodingService: _FakeGeocodingService(),
      );

      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.text('Sources'), findsOneWidget);
      expect(find.byType(RangeSlider), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets(
      'shows a message instead of a search when the destination cannot be '
      'geocoded',
      (tester) async {
        await _pump(
          tester,
          isPublic: false,
          members: [_editorMember],
          geocodingService: _EmptyGeocodingService(),
        );

        await tester.tap(find.text('Stay'));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
        expect(
          find.textContaining('Could not find a location'),
          findsOneWidget,
        );
      },
    );
  });

  group('member long-press actions', () {
    // canManage requires the current user to be the owner AND the target
    // row to not be the owner's own row — _editorMember ('user-1') is an
    // editor, not the owner, so these tests use an explicit owner member
    // instead to exercise the manage-gated rows.
    final ownerMember = GroupMember(
      userId: 'user-1',
      userName: 'Arpit',
      role: GroupMemberRole.owner,
      joinedAt: DateTime.utc(2026),
    );
    final otherMember = GroupMember(
      userId: 'user-2',
      userName: 'Bob',
      role: GroupMemberRole.viewer,
      joinedAt: DateTime.utc(2026),
    );

    testWidgets(
      'owner long-pressing another member sees Message privately, Make '
      'Editor, and Remove from trip',
      (tester) async {
        await _pump(
          tester,
          isPublic: false,
          members: [ownerMember, otherMember],
        );

        await tester.ensureVisible(find.text('Bob'));
        await tester.longPress(find.text('Bob'));
        await tester.pumpAndSettle();

        expect(find.text('Message privately'), findsOneWidget);
        expect(find.text('Make Editor'), findsOneWidget);
        expect(find.text('Remove from trip'), findsOneWidget);
      },
    );

    testWidgets('long-pressing your own row never offers Message privately', (
      tester,
    ) async {
      await _pump(tester, isPublic: false, members: [ownerMember, otherMember]);

      await tester.ensureVisible(find.text('Arpit'));
      await tester.longPress(find.text('Arpit'));
      await tester.pumpAndSettle();

      expect(find.text('Message privately'), findsNothing);
    });

    testWidgets('a non-owner long-pressing another member sees only Message '
        'privately, no manage actions', (tester) async {
      await _pump(
        tester,
        isPublic: false,
        ownerId: 'someone-else',
        members: [_editorMember, otherMember],
      );

      await tester.ensureVisible(find.text('Bob'));
      await tester.longPress(find.text('Bob'));
      await tester.pumpAndSettle();

      expect(find.text('Message privately'), findsOneWidget);
      expect(find.text('Make Editor'), findsNothing);
      expect(find.text('Remove from trip'), findsNothing);
    });

    testWidgets(
      'a row with no long-press actions available does not open a sheet',
      (tester) async {
        // A non-owner long-pressing their own row: no manage rights, and
        // "Message privately" is excluded for your own row.
        await _pump(
          tester,
          isPublic: false,
          ownerId: 'someone-else',
          members: [_editorMember, otherMember],
        );

        await tester.ensureVisible(find.text('Arpit'));
        await tester.longPress(find.text('Arpit'));
        await tester.pumpAndSettle();

        expect(find.text('Message privately'), findsNothing);
        expect(find.text('Remove from trip'), findsNothing);
      },
    );

    testWidgets('tapping "Message privately" resolves a conversation via the '
        'repository', (tester) async {
      final dmRepo = MockDirectMessageRepository();
      when(
        () => dmRepo.getOrCreateConversation('user-2'),
      ).thenAnswer((_) async => const Left(ServerFailure('boom')));

      await _pump(
        tester,
        isPublic: false,
        members: [ownerMember, otherMember],
        directMessageRepository: dmRepo,
      );

      await tester.ensureVisible(find.text('Bob'));
      await tester.longPress(find.text('Bob'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Message privately'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      verify(() => dmRepo.getOrCreateConversation('user-2')).called(1);
      // Left(...) surfaces as a snackbar rather than navigating — this
      // sidesteps needing a full GoRouter harness just to exercise the
      // repository call itself.
      expect(find.text('boom'), findsOneWidget);
    });

    testWidgets(
      'tapping "Remove from trip" in the sheet opens the confirm dialog',
      (tester) async {
        await _pump(
          tester,
          isPublic: false,
          members: [ownerMember, otherMember],
        );

        await tester.ensureVisible(find.text('Bob'));
        await tester.longPress(find.text('Bob'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove from trip'));
        await tester.pumpAndSettle();

        expect(find.text('Remove member?'), findsOneWidget);
        expect(find.text('Remove Bob from this trip?'), findsOneWidget);
      },
    );
  });
}
