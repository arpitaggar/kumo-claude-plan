import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/hitchhiker/domain/entities/hitchhiker.dart';
import 'package:kumo_claude/features/hitchhiker/domain/repositories/hitchhiker_repository.dart';
import 'package:kumo_claude/features/hitchhiker/presentation/providers/hitchhiker_provider.dart';
import 'package:kumo_claude/features/hitchhiker/presentation/widgets/hitchhiker_tab.dart';
import 'package:mocktail/mocktail.dart';

class MockHitchhikerRepository extends Mock implements HitchhikerRepository {}

void main() {
  late MockHitchhikerRepository mockRepo;

  setUp(() {
    mockRepo = MockHitchhikerRepository();
  });

  Future<void> pumpTab(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hitchhikerRepositoryProvider.overrideWithValue(mockRepo)],
        child: const MaterialApp(
          home: Scaffold(body: HitchhikerTab(itineraryId: 'trip-1')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('hitchhikerJoinLink', () {
    test('encodes the token into a kumo:// deep link', () {
      expect(hitchhikerJoinLink('abc-123'), 'kumo://hitchhiker?token=abc-123');
    });
  });

  group('HitchhikerTab', () {
    testWidgets('renders without crash', (tester) async {
      when(
        () => mockRepo.listHitchhikers('trip-1'),
      ).thenAnswer((_) async => const Right([]));

      await pumpTab(tester);
    });

    testWidgets('shows the name field and explanation', (tester) async {
      when(
        () => mockRepo.listHitchhikers('trip-1'),
      ).thenAnswer((_) async => const Right([]));

      await pumpTab(tester);

      expect(find.text('First name or nickname'), findsOneWidget);
      expect(find.textContaining('Add someone by name only'), findsOneWidget);
    });

    testWidgets('shows the empty-roster message when there are no '
        'Hitchhikers yet', (tester) async {
      when(
        () => mockRepo.listHitchhikers('trip-1'),
      ).thenAnswer((_) async => const Right([]));

      await pumpTab(tester);

      expect(find.text('No Hitchhikers on this trip yet.'), findsOneWidget);
    });

    testWidgets('lists an existing Hitchhiker by name', (tester) async {
      when(() => mockRepo.listHitchhikers('trip-1')).thenAnswer(
        (_) async => Right([
          Hitchhiker(
            id: 'hh-1',
            itineraryId: 'trip-1',
            displayName: 'Priya',
            accessToken: 'tok-1',
            createdAt: DateTime(2026),
          ),
        ]),
      );

      await pumpTab(tester);

      expect(find.text('Priya'), findsOneWidget);
      expect(find.text('Hitchhiker'), findsOneWidget);
    });

    testWidgets('shows "Removed" (no action buttons) for a revoked '
        'Hitchhiker', (tester) async {
      when(() => mockRepo.listHitchhikers('trip-1')).thenAnswer(
        (_) async => Right([
          Hitchhiker(
            id: 'hh-1',
            itineraryId: 'trip-1',
            displayName: 'Sam',
            accessToken: 'tok-1',
            createdAt: DateTime(2026),
            revokedAt: DateTime(2026, 1, 2),
          ),
        ]),
      );

      await pumpTab(tester);

      expect(find.text('Removed'), findsOneWidget);
      expect(find.byIcon(Icons.person_remove_outlined), findsNothing);
    });

    testWidgets('typing a name and tapping add calls createHitchhiker and '
        'shows the share sheet', (tester) async {
      when(
        () => mockRepo.listHitchhikers('trip-1'),
      ).thenAnswer((_) async => const Right([]));
      when(
        () => mockRepo.createHitchhiker(
          itineraryId: 'trip-1',
          displayName: 'Priya',
        ),
      ).thenAnswer(
        (_) async => Right(
          Hitchhiker(
            id: 'hh-1',
            itineraryId: 'trip-1',
            displayName: 'Priya',
            accessToken: 'tok-1',
            createdAt: DateTime(2026),
          ),
        ),
      );

      await pumpTab(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'First name or nickname'),
        'Priya',
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      verify(
        () => mockRepo.createHitchhiker(
          itineraryId: 'trip-1',
          displayName: 'Priya',
        ),
      ).called(1);
      expect(find.text('Priya is on the trip'), findsOneWidget);
    });

    testWidgets('tapping remove shows a confirmation dialog, and '
        'confirming calls revokeHitchhiker', (tester) async {
      when(() => mockRepo.listHitchhikers('trip-1')).thenAnswer(
        (_) async => Right([
          Hitchhiker(
            id: 'hh-1',
            itineraryId: 'trip-1',
            displayName: 'Priya',
            accessToken: 'tok-1',
            createdAt: DateTime(2026),
          ),
        ]),
      );
      when(
        () => mockRepo.revokeHitchhiker('hh-1'),
      ).thenAnswer((_) async => const Right(null));

      await pumpTab(tester);
      await tester.tap(find.byIcon(Icons.person_remove_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Remove Hitchhiker?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.revokeHitchhiker('hh-1')).called(1);
    });
  });
}
