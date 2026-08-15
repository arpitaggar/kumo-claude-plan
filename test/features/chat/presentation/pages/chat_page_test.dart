import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:kumo_claude/features/chat/domain/entities/message.dart';
import 'package:kumo_claude/features/chat/domain/entities/message_attachment.dart';
import 'package:kumo_claude/features/chat/domain/entities/message_read_receipt.dart';
import 'package:kumo_claude/features/chat/domain/repositories/chat_repository.dart';
import 'package:kumo_claude/features/chat/presentation/pages/chat_page.dart';
import 'package:kumo_claude/features/chat/presentation/providers/chat_provider.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/itinerary_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

// chat_page.dart previously had zero test coverage — deliberately deferred
// (see docs/SOLID_AUDIT.md and docs/Checklist.md) because the typing
// indicator subscribes to a raw Supabase RealtimeChannel from initState,
// which this suite doesn't attempt to abstract or assert on (out of scope,
// same call already made for production code). Everything else on the page
// — message list rendering, sending, pagination, read receipts — is
// perfectly testable behind the existing chatRepositoryProvider/
// chatRemoteDataSourceProvider/chatStreamProvider seams.
//
// Writing this suite surfaced one real bug, fixed alongside these tests:
// ChatPage.dispose() deferred its activeChatIdProvider write to a
// Future.microtask (Riverpod forbids a synchronous provider write during
// dispose), but never guarded against the ProviderContainer itself already
// being gone by the time that microtask ran — a widget-teardown race threw
// an uncaught StateError. See chat_page.dart's dispose() for the fix.

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

class MockChatRepository extends Mock implements ChatRepository {}

class MockChatRemoteDataSource extends Mock implements ChatRemoteDataSource {}

const _tripId = 'trip-1';
const _me = 'user-me';
const _other = 'user-other';

const _summary = ExpenseSummary(
  totalSpent: 0,
  spentByCategory: {},
  memberBalances: {},
);

TravelItinerary _trip() => TravelItinerary(
  id: _tripId,
  title: 'Kyoto Trip',
  ownerId: _me,
  startDate: DateTime.utc(2026, 6),
  endDate: DateTime.utc(2026, 6, 7),
  totalBudget: 1000,
  currencyCode: 'USD',
  members: const [],
  items: const [],
  expenseSummary: _summary,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Message _msg({
  required String id,
  required String senderId,
  String senderName = 'Someone',
  String content = 'hello',
  DateTime? createdAt,
  List<String> readBy = const [],
  List<MessageAttachment> attachments = const [],
}) => Message(
  id: id,
  itineraryId: _tripId,
  senderId: senderId,
  senderName: senderName,
  content: content,
  createdAt: createdAt ?? DateTime.utc(2026, 6, 1, 10),
  readBy: readBy,
  attachments: attachments,
);

class _Harness {
  _Harness({required this.chatRepo, required this.dataSource});

  final MockChatRepository chatRepo;
  final MockChatRemoteDataSource dataSource;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required Stream<List<Message>> messages,
}) async {
  final authRepo = MockAuthRepository();
  when(authRepo.getCurrentUser).thenAnswer(
    (_) async => Right(
      User(id: _me, email: 'me@example.com', createdAt: DateTime.utc(2026)),
    ),
  );

  final chatRepo = MockChatRepository();
  when(
    () => chatRepo.fetchMessagesBefore(
      itineraryId: any(named: 'itineraryId'),
      before: any(named: 'before'),
    ),
  ).thenAnswer((_) async => const Right([]));
  when(
    () => chatRepo.getReadReceipts(any()),
  ).thenAnswer((_) async => const Right([]));

  final dataSource = MockChatRemoteDataSource();
  when(() => dataSource.markMessagesRead(any())).thenAnswer((_) async {});

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
        chatStreamProvider(_tripId).overrideWith((ref) => messages),
        itineraryStreamProvider(
          _tripId,
        ).overrideWith((ref) => Stream.value(_trip())),
        chatRepositoryProvider.overrideWithValue(chatRepo),
        chatRemoteDataSourceProvider.overrideWithValue(dataSource),
      ],
      child: const MaterialApp(home: ChatPage(itineraryId: _tripId)),
    ),
  );

  // A plain pump (not pumpAndSettle) — the typing-indicator's real
  // RealtimeChannel.subscribe() never settles under the test project's
  // dummy URL, and this page has no other open-ended animation that needs
  // pumpAndSettle to reach a steady state.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  return _Harness(chatRepo: chatRepo, dataSource: dataSource);
}

void main() {
  setUpAll(initTestSupabase);

  group('ChatPage', () {
    testWidgets('shows a loading indicator while messages load', (
      tester,
    ) async {
      await _pump(tester, messages: const Stream.empty());
      expect(find.text('Loading messages…'), findsOneWidget);
    });

    testWidgets('shows the empty state once loaded with no messages', (
      tester,
    ) async {
      await _pump(tester, messages: Stream.value(const []));
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.text('Say hello to your travel crew!'), findsOneWidget);
    });

    testWidgets('shows an error message when the stream fails', (tester) async {
      await _pump(
        tester,
        messages: Stream<List<Message>>.error(Exception('Could not load chat')),
      );
      expect(find.textContaining('Could not load chat'), findsOneWidget);
    });

    testWidgets('renders messages from both the current user and others', (
      tester,
    ) async {
      await _pump(
        tester,
        messages: Stream.value([
          _msg(
            id: 'm1',
            senderId: _other,
            senderName: 'Dudu',
            content: 'hi there',
          ),
          _msg(id: 'm2', senderId: _me, content: 'hello back'),
        ]),
      );
      expect(find.text('hi there'), findsOneWidget);
      expect(find.text('hello back'), findsOneWidget);
      // Sender name is only shown above a message from someone else.
      expect(find.text('Dudu'), findsOneWidget);
    });

    testWidgets(
      'does not show a sender name label above the current user\'s own message',
      (tester) async {
        await _pump(
          tester,
          messages: Stream.value([
            _msg(id: 'm1', senderId: _me, senderName: 'Arpit', content: 'solo'),
          ]),
        );
        expect(find.text('solo'), findsOneWidget);
        expect(find.text('Arpit'), findsNothing);
      },
    );

    testWidgets('shows the trip title in the app bar', (tester) async {
      await _pump(tester, messages: Stream.value(const []));
      expect(find.text('Kyoto Trip'), findsOneWidget);
      expect(find.text('Group chat'), findsOneWidget);
    });

    testWidgets('sends a typed message and clears the input', (tester) async {
      final h = await _pump(tester, messages: Stream.value(const []));
      when(
        () => h.chatRepo.sendMessage(
          itineraryId: any(named: 'itineraryId'),
          senderId: any(named: 'senderId'),
          senderName: any(named: 'senderName'),
          content: any(named: 'content'),
          attachmentStoragePath: any(named: 'attachmentStoragePath'),
          attachmentUrl: any(named: 'attachmentUrl'),
          attachmentFileName: any(named: 'attachmentFileName'),
          attachmentMimeType: any(named: 'attachmentMimeType'),
          attachmentSizeBytes: any(named: 'attachmentSizeBytes'),
          attachmentKind: any(named: 'attachmentKind'),
        ),
      ).thenAnswer((_) async => const Right(null));

      await tester.enterText(find.byType(TextField), 'a new message');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Omitted attachment* named args below fall back to their (null)
      // defaults, which is exactly what a plain-text send should produce.
      verify(
        () => h.chatRepo.sendMessage(
          itineraryId: _tripId,
          senderId: _me,
          senderName: any(named: 'senderName'),
          content: 'a new message',
        ),
      ).called(1);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('shows a snackbar when sending fails', (tester) async {
      final h = await _pump(tester, messages: Stream.value(const []));
      when(
        () => h.chatRepo.sendMessage(
          itineraryId: any(named: 'itineraryId'),
          senderId: any(named: 'senderId'),
          senderName: any(named: 'senderName'),
          content: any(named: 'content'),
          attachmentStoragePath: any(named: 'attachmentStoragePath'),
          attachmentUrl: any(named: 'attachmentUrl'),
          attachmentFileName: any(named: 'attachmentFileName'),
          attachmentMimeType: any(named: 'attachmentMimeType'),
          attachmentSizeBytes: any(named: 'attachmentSizeBytes'),
          attachmentKind: any(named: 'attachmentKind'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('send failed')));

      await tester.enterText(find.byType(TextField), 'will fail');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('send failed'), findsOneWidget);
    });

    testWidgets('the send button does nothing while the input is empty', (
      tester,
    ) async {
      final h = await _pump(tester, messages: Stream.value(const []));

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      verifyNever(
        () => h.chatRepo.sendMessage(
          itineraryId: any(named: 'itineraryId'),
          senderId: any(named: 'senderId'),
          senderName: any(named: 'senderName'),
          content: any(named: 'content'),
        ),
      );
    });

    testWidgets('shows "Load earlier messages" while more history may exist', (
      tester,
    ) async {
      await _pump(
        tester,
        messages: Stream.value([_msg(id: 'm1', senderId: _me)]),
      );
      // _hasMore starts true until a fetch actually comes back empty — see
      // the "becomes Beginning of conversation once exhausted" test below.
      expect(find.text('Load earlier messages'), findsOneWidget);
    });

    testWidgets(
      'tapping "Load earlier messages" fetches and prepends older messages',
      (tester) async {
        final h = await _pump(
          tester,
          messages: Stream.value([
            _msg(id: 'm2', senderId: _me, content: 'newer'),
          ]),
        );
        when(
          () => h.chatRepo.fetchMessagesBefore(
            itineraryId: any(named: 'itineraryId'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => Right([_msg(id: 'm1', senderId: _me, content: 'older')]),
        );

        await tester.tap(find.text('Load earlier messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('older'), findsOneWidget);
        expect(find.text('newer'), findsOneWidget);
      },
    );

    testWidgets(
      '"Load earlier messages" becomes "Beginning of conversation" once exhausted',
      (tester) async {
        final h = await _pump(
          tester,
          messages: Stream.value([_msg(id: 'm1', senderId: _me)]),
        );
        when(
          () => h.chatRepo.fetchMessagesBefore(
            itineraryId: any(named: 'itineraryId'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async => const Right([]));

        await tester.tap(find.text('Load earlier messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Beginning of conversation'), findsOneWidget);
        expect(find.text('Load earlier messages'), findsNothing);
      },
    );

    testWidgets('long-pressing your own message opens the read-receipt sheet', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        messages: Stream.value([
          _msg(id: 'm1', senderId: _me, content: 'seen?'),
        ]),
      );
      when(() => h.chatRepo.getReadReceipts('m1')).thenAnswer(
        (_) async => Right([
          MessageReadReceipt(
            userId: _other,
            displayName: 'Dudu',
            readAt: DateTime.utc(2026, 6, 1, 11),
          ),
        ]),
      );

      await tester.longPress(find.text('seen?'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Message info'), findsOneWidget);
      expect(find.text('Dudu'), findsOneWidget);
    });

    testWidgets(
      'long-pressing a message from someone else does not open a sheet',
      (tester) async {
        await _pump(
          tester,
          messages: Stream.value([
            _msg(id: 'm1', senderId: _other, content: 'not yours'),
          ]),
        );

        await tester.longPress(find.text('not yours'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Message info'), findsNothing);
      },
    );

    testWidgets(
      'read-receipt sheet shows "Delivered — not seen yet" with no receipts',
      (tester) async {
        await _pump(
          tester,
          messages: Stream.value([
            _msg(id: 'm1', senderId: _me, content: 'ping'),
          ]),
        );

        await tester.longPress(find.text('ping'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Delivered — not seen yet'), findsOneWidget);
      },
    );

    testWidgets('a Hitchhiker-authored message (no real sender id) renders', (
      tester,
    ) async {
      // Regression guard for the fallback documented in
      // lib/features/chat/CLAUDE.md: MessageModel.fromJson falls back to
      // hitchhiker_id when sender_id is null, producing an id that can
      // never equal a real currentUserId. At the entity level that's just
      // an ordinary non-me senderId — this confirms the page renders it
      // like any other message rather than crashing.
      await _pump(
        tester,
        messages: Stream.value([
          _msg(
            id: 'm1',
            senderId: 'hitchhiker-abc123',
            senderName: 'Guest Sam',
            content: 'thanks for the invite!',
          ),
        ]),
      );
      expect(find.text('thanks for the invite!'), findsOneWidget);
      expect(find.text('Guest Sam'), findsOneWidget);
    });
  });
}
