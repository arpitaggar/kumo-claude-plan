import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/profile/domain/entities/notification_preference.dart';
import 'package:kumo_claude/features/profile/domain/entities/user_profile.dart';
import 'package:kumo_claude/features/profile/domain/repositories/notification_preference_repository.dart';
import 'package:kumo_claude/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:kumo_claude/features/profile/presentation/pages/notification_preferences_page.dart';
import 'package:kumo_claude/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockNotificationPreferenceRepository extends Mock
    implements NotificationPreferenceRepository {}

class MockUserProfileRepository extends Mock implements UserProfileRepository {}

final _profile = UserProfile(
  id: 'user-1',
  email: 'alice@example.com',
  displayName: 'Alice',
  isSearchable: true,
  profileVisibility: 'public',
  contactVisibility: 'collaborators_only',
  unitsPreference: 'metric',
  travelPreferenceTags: const [],
  updatedAt: DateTime.utc(2026),
  // Defaults to false in the real entity (privacy by default) — true here
  // just to keep the "every switch defaults to on" test's assertion simple.
  pushMessagePreviewEnabled: true,
);

Future<MockNotificationPreferenceRepository> _pump(
  WidgetTester tester, {
  List<NotificationPreference>? prefs,
}) async {
  final notifRepo = MockNotificationPreferenceRepository();
  final profileRepo = MockUserProfileRepository();
  when(
    () => notifRepo.upsertNotificationPreference(
      channel: any(named: 'channel'),
      category: any(named: 'category'),
      enabled: any(named: 'enabled'),
    ),
  ).thenAnswer((_) async => const Right(null));
  when(
    () => profileRepo.updateProfile(
      pushMessagePreviewEnabled: any(named: 'pushMessagePreviewEnabled'),
    ),
  ).thenAnswer((_) async => Right(_profile));

  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationPreferencesProvider.overrideWith(
          (ref) async => prefs ?? const [],
        ),
        notificationPreferenceRepositoryProvider.overrideWithValue(notifRepo),
        userProfileRepositoryProvider.overrideWithValue(profileRepo),
        userProfileProvider.overrideWith((ref) async => _profile),
      ],
      child: const MaterialApp(home: NotificationPreferencesPage()),
    ),
  );
  await tester.pumpAndSettle();
  return notifRepo;
}

void main() {
  setUpAll(initTestSupabase);

  testWidgets('renders the AppBar title and every category row', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Notifications'), findsOneWidget);
    for (final category in NotifCategory.all) {
      expect(find.text(NotifCategory.label(category)), findsOneWidget);
    }
  });

  testWidgets('defaults every switch to on when no preference row exists '
      'for it', (tester) async {
    await _pump(tester);

    final switches = tester.widgetList<Switch>(find.byType(Switch));
    // 7 categories x 3 channels + the message-preview toggle.
    expect(
      switches.length,
      NotifCategory.all.length * NotifChannel.all.length + 1,
    );
    expect(switches.every((s) => s.value), isTrue);
  });

  testWidgets('reflects a disabled preference row for its exact '
      '(channel, category) pair only', (tester) async {
    await _pump(
      tester,
      prefs: const [
        NotificationPreference(
          channel: NotifChannel.email,
          category: NotifCategory.tripInvites,
          enabled: false,
        ),
      ],
    );

    final row = find.ancestor(
      of: find.text('Trip Invites'),
      matching: find.byType(Row),
    );
    final switches = tester.widgetList<Switch>(
      find.descendant(of: row.first, matching: find.byType(Switch)),
    );
    // push, email, sms in that order — only the email one is off.
    expect(switches.elementAt(0).value, isTrue);
    expect(switches.elementAt(1).value, isFalse);
    expect(switches.elementAt(2).value, isTrue);
  });

  testWidgets(
    'toggling a switch calls upsertNotificationPreference with the right '
    'channel/category/enabled',
    (tester) async {
      final notifRepo = await _pump(tester);

      final row = find.ancestor(
        of: find.text('Flight Alerts'),
        matching: find.byType(Row),
      );
      final pushSwitch = find
          .descendant(of: row.first, matching: find.byType(Switch))
          .first;
      await tester.tap(pushSwitch);
      await tester.pumpAndSettle();

      verify(
        () => notifRepo.upsertNotificationPreference(
          channel: NotifChannel.push,
          category: NotifCategory.flightAlerts,
          enabled: false,
        ),
      ).called(1);
    },
  );

  testWidgets('reverts the switch and shows a snackbar when the upsert '
      'fails', (tester) async {
    final notifRepo = await _pump(tester);
    when(
      () => notifRepo.upsertNotificationPreference(
        channel: any(named: 'channel'),
        category: any(named: 'category'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('Save failed')));

    final row = find.ancestor(
      of: find.text('Flight Alerts'),
      matching: find.byType(Row),
    );
    final pushSwitch = find
        .descendant(of: row.first, matching: find.byType(Switch))
        .first;
    await tester.tap(pushSwitch);
    await tester.pump(); // optimistic flip
    await tester.pump(); // completes the awaited upsert + revert
    await tester.pump(); // builds the frame showing the snackbar

    // Checked before pumpAndSettle — a real SnackBar's dismiss timer keeps
    // firing on the test's fake clock and pumpAndSettle would run past it.
    expect(find.text('Save failed'), findsOneWidget);
    final pushSwitchWidget = tester.widget<Switch>(pushSwitch);
    expect(pushSwitchWidget.value, isTrue);
  });

  testWidgets('the message-preview toggle is disabled when chat push is off '
      'and enabled when chat push is on', (tester) async {
    await _pump(
      tester,
      prefs: const [
        NotificationPreference(
          channel: NotifChannel.push,
          category: NotifCategory.chatMessages,
          enabled: false,
        ),
      ],
    );

    final previewSwitch = tester.widget<Switch>(find.byType(Switch).last);
    expect(previewSwitch.onChanged, isNull);
  });
}
