import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/hitchhiker/domain/entities/hitchhiker_trip_view.dart';
import 'package:kumo_claude/features/hitchhiker/domain/repositories/hitchhiker_access_repository.dart';
import 'package:kumo_claude/features/hitchhiker/presentation/pages/hitchhiker_screen.dart';
import 'package:kumo_claude/features/hitchhiker/presentation/providers/hitchhiker_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockHitchhikerAccessRepository extends Mock
    implements HitchhikerAccessRepository {}

void main() {
  late MockHitchhikerAccessRepository mockRepo;

  final tView = HitchhikerTripView(
    hitchhikerId: 'hh-1',
    displayName: 'Priya',
    itineraryId: 'trip-1',
    tripTitle: 'Tokyo Trip',
    tripDescription: 'Spring adventure',
    startDate: DateTime(2026, 4, 1),
    endDate: DateTime(2026, 4, 10),
    status: 'active',
    messages: [
      HitchhikerMessage(
        id: 'msg-1',
        senderName: 'Alex',
        content: 'Hey Priya!',
        createdAt: DateTime(2026, 3, 1, 12),
        isYou: false,
      ),
    ],
    suggestions: [
      HitchhikerSuggestion(
        id: 'sug-1',
        title: "Nonna's",
        description: 'Great pasta',
        suggestedByName: 'Priya',
        status: 'pending',
        createdAt: DateTime(2026, 3, 2),
      ),
    ],
  );

  setUp(() {
    mockRepo = MockHitchhikerAccessRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hitchhikerAccessRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(home: HitchhikerScreen(token: 'tok-1')),
      ),
    );
  }

  group('HitchhikerScreen', () {
    testWidgets('shows a loading indicator, then the trip header once '
        'resolved', (tester) async {
      when(
        () => mockRepo.getTripView('tok-1'),
      ).thenAnswer((_) async => Right(tView));

      await pumpScreen(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Tokyo Trip'), findsOneWidget);
      expect(find.text("You're viewing as Priya"), findsOneWidget);
    });

    testWidgets('shows an invalid-link message when the token is rejected', (
      tester,
    ) async {
      when(() => mockRepo.getTripView('tok-1')).thenAnswer(
        (_) async => const Left(
          ServerFailure('This collaborator link is no longer valid.'),
        ),
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('This link is no longer valid'), findsOneWidget);
    });

    testWidgets('Chat tab shows existing messages', (tester) async {
      when(
        () => mockRepo.getTripView('tok-1'),
      ).thenAnswer((_) async => Right(tView));

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Hey Priya!'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
    });

    testWidgets('sending a chat message calls sendMessage and clears the '
        'field', (tester) async {
      when(
        () => mockRepo.getTripView('tok-1'),
      ).thenAnswer((_) async => Right(tView));
      when(
        () => mockRepo.sendMessage(token: 'tok-1', content: 'hello there'),
      ).thenAnswer((_) async => const Right(null));

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Message…'),
        'hello there',
      );
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      verify(
        () => mockRepo.sendMessage(token: 'tok-1', content: 'hello there'),
      ).called(1);
    });

    testWidgets('Suggest tab shows existing suggestions and their status', (
      tester,
    ) async {
      when(
        () => mockRepo.getTripView('tok-1'),
      ).thenAnswer((_) async => Right(tView));

      await pumpScreen(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suggest'));
      await tester.pumpAndSettle();

      expect(find.text("Nonna's"), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('submitting a suggestion calls suggestItem', (tester) async {
      when(
        () => mockRepo.getTripView('tok-1'),
      ).thenAnswer((_) async => Right(tView));
      when(
        () => mockRepo.suggestItem(
          token: 'tok-1',
          title: 'Beach day',
          description: null,
        ),
      ).thenAnswer((_) async => const Right(null));

      await pumpScreen(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suggest'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'What do you suggest?'),
        'Beach day',
      );
      await tester.tap(find.text('Send suggestion'));
      await tester.pumpAndSettle();

      verify(
        () => mockRepo.suggestItem(
          token: 'tok-1',
          title: 'Beach day',
          description: null,
        ),
      ).called(1);
    });
  });
}
