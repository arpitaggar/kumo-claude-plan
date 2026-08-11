import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/gamification/domain/entities/xp_event.dart';
import 'package:kumo_claude/features/gamification/presentation/pages/achievements_page.dart';
import 'package:kumo_claude/features/gamification/presentation/providers/gamification_provider.dart';

import '../../../../helpers/test_helpers.dart';

XpEvent _event(String sourceType, int amount, {DateTime? createdAt}) => XpEvent(
  id: 'evt-$sourceType-$amount',
  userId: 'user-1',
  amount: amount,
  reason: sourceType,
  sourceType: sourceType,
  sourceId: 'src-1',
  createdAt: createdAt ?? DateTime.now(),
);

Future<void> _pump(WidgetTester tester, List<XpEvent> events) async {
  // The badge grid + recent-activity list push content below a default
  // 800x600 test surface, which a ListView only lazily builds within —
  // same fix as profile_page_test.dart / create_itinerary_page_test.dart.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [xpEventsProvider.overrideWith((ref) async => events)],
      child: const MaterialApp(home: AchievementsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestSupabase);

  testWidgets('shows level 1 and the empty-activity message with no XP', (
    tester,
  ) async {
    await _pump(tester, const []);

    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('0 XP total'), findsOneWidget);
    expect(find.textContaining('start earning XP'), findsOneWidget);
  });

  testWidgets('earned badges show their label; recent activity lists '
      'events with their XP amount', (tester) async {
    await _pump(tester, [
      _event('trip_created', 10),
      _event('post_published', 15),
    ]);

    // First Steps (tripsCreated >= 1) and Storyteller (postsPublished >= 1)
    // are both earned.
    expect(find.text('First Steps'), findsOneWidget);
    expect(find.text('Storyteller'), findsOneWidget);

    expect(find.text('+10 XP'), findsOneWidget);
    expect(find.text('+15 XP'), findsOneWidget);
  });

  testWidgets('all 8 badges render regardless of earned state', (tester) async {
    await _pump(tester, const []);

    for (final label in [
      'First Steps',
      'Wanderer',
      'Globetrotter',
      'Storyteller',
      'Popular',
      'Influencer',
      'Conversationalist',
      'Century Club',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
