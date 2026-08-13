import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumo_claude/config/constants.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/presentation/widgets/itinerary_card.dart';

// Regression coverage added 2026-08-13 after the Home page's trash icon
// deleted a real trip with zero confirmation — see docs/Checklist.md. The
// detail page's own delete button already confirmed via an AlertDialog;
// this card (used by both home_page.dart and trips_page.dart) previously
// called onDelete directly from the icon's onPressed.

const _summary = ExpenseSummary(
  totalSpent: 0,
  spentByCategory: {},
  memberBalances: {},
);

TravelItinerary _trip() => TravelItinerary(
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
);

// ItineraryCard's delete confirmation uses GoRouter's context.pop(), matching
// this codebase's convention throughout (see itinerary_detail_page.dart's own
// _confirmDelete) — needs a real GoRouter ancestor, not just a bare
// MaterialApp, or GoRouter.of(context) throws.
Widget _wrap(Widget child) => MaterialApp.router(
  routerConfig: GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: child),
      ),
    ],
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required VoidCallback onDelete,
}) async {
  await tester.pumpWidget(
    _wrap(ItineraryCard(itinerary: _trip(), onTap: () {}, onDelete: onDelete)),
  );
}

void main() {
  testWidgets('no delete icon renders when onDelete is null', (tester) async {
    await tester.pumpWidget(
      _wrap(ItineraryCard(itinerary: _trip(), onTap: () {})),
    );

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('tapping the delete icon shows a confirmation dialog instead '
      'of deleting immediately', (tester) async {
    var deleted = false;
    await _pump(tester, onDelete: () => deleted = true);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete trip?'), findsOneWidget);
    expect(find.textContaining('KumoTest'), findsWidgets);
    expect(deleted, isFalse);
  });

  testWidgets('confirming the dialog calls onDelete', (tester) async {
    var deleted = false;
    await _pump(tester, onDelete: () => deleted = true);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });

  testWidgets('cancelling the dialog does not call onDelete', (tester) async {
    var deleted = false;
    await _pump(tester, onDelete: () => deleted = true);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(deleted, isFalse);
    expect(find.text('Delete trip?'), findsNothing);
  });
}
