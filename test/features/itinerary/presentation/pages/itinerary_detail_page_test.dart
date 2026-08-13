import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/config/constants.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
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

const _summary = ExpenseSummary(
  totalSpent: 0,
  spentByCategory: {},
  memberBalances: {},
);

TravelItinerary _trip({required bool isPublic}) => TravelItinerary(
  id: 'trip-1',
  title: 'KumoTest',
  ownerId: 'user-1',
  startDate: DateTime.utc(2026, 6, 8),
  endDate: DateTime.utc(2026, 6, 15),
  totalBudget: 9000,
  currencyCode: AppConstants.defaultCurrency,
  members: const [],
  items: const [],
  expenseSummary: _summary,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  isPublic: isPublic,
);

Future<void> _pump(WidgetTester tester, {required bool isPublic}) async {
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
        itineraryStreamProvider(
          'trip-1',
        ).overrideWith((ref) => Stream.value(_trip(isPublic: isPublic))),
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
}
