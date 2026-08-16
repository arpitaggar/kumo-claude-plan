import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/crash_reporting/crash_reporter.dart';
import 'package:kumo_claude/core/crash_reporting/crash_reporting_providers.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/chat/domain/entities/message_read_receipt.dart';
import 'package:kumo_claude/features/direct_messages/data/datasources/direct_message_remote_datasource.dart';
import 'package:kumo_claude/features/direct_messages/domain/entities/direct_message.dart';
import 'package:kumo_claude/features/direct_messages/domain/entities/dm_conversation.dart';
import 'package:kumo_claude/features/direct_messages/domain/repositories/direct_message_repository.dart';
import 'package:kumo_claude/features/direct_messages/presentation/pages/dm_thread_page.dart';
import 'package:kumo_claude/features/direct_messages/presentation/providers/direct_message_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

class MockDirectMessageRepository extends Mock
    implements DirectMessageRepository {}

class MockDirectMessageRemoteDataSource extends Mock
    implements DirectMessageRemoteDataSource {}

class MockCrashReporter extends Mock implements CrashReporter {}

const _convoId = 'conv-1';
const _me = 'user-me';
const _other = 'user-other';

DirectMessage _msg({
  required String id,
  required String senderId,
  String senderName = 'Someone',
  String content = 'hello',
  DateTime? createdAt,
  List<String> readBy = const [],
}) => DirectMessage(
  id: id,
  dmConversationId: _convoId,
  senderId: senderId,
  senderName: senderName,
  content: content,
  createdAt: createdAt ?? DateTime.utc(2026, 6, 1, 10),
  readBy: readBy,
);

class _Harness {
  _Harness({required this.repo, required this.dataSource});

  final MockDirectMessageRepository repo;
  final MockDirectMessageRemoteDataSource dataSource;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required Stream<List<DirectMessage>> messages,
  bool blockedByMe = false,
}) async {
  final authRepo = MockAuthRepository();
  when(authRepo.getCurrentUser).thenAnswer(
    (_) async => Right(
      User(id: _me, email: 'me@example.com', createdAt: DateTime.utc(2026)),
    ),
  );

  final repo = MockDirectMessageRepository();
  when(
    () => repo.fetchMessagesBefore(
      conversationId: any(named: 'conversationId'),
      before: any(named: 'before'),
    ),
  ).thenAnswer((_) async => const Right([]));
  when(
    () => repo.getReadReceipts(any()),
  ).thenAnswer((_) async => const Right([]));
  // A mutable flag (not a fixed stub) so that after blockUser() succeeds,
  // the widget's re-fetch of isBlockedByMe (triggered by ref.invalidate in
  // DmThreadPage's _confirmBlock) actually observes the new state, matching
  // how the real RPC-then-re-check flow behaves against a real backend.
  var blocked = blockedByMe;
  when(() => repo.isBlockedByMe(any())).thenAnswer((_) async => Right(blocked));
  when(() => repo.unblockUser(any())).thenAnswer((_) async {
    blocked = false;
    return const Right(null);
  });
  when(() => repo.blockUser(any())).thenAnswer((_) async {
    blocked = true;
    return const Right(null);
  });

  final dataSource = MockDirectMessageRemoteDataSource();
  when(() => dataSource.markMessagesRead(any())).thenAnswer((_) async {});

  final crashReporter = MockCrashReporter();
  when(
    () => crashReporter.recordError(
      any(),
      any(),
      reason: any(named: 'reason'),
      fatal: any(named: 'fatal'),
    ),
  ).thenAnswer((_) async {});

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
        dmMessageStreamProvider(_convoId).overrideWith((ref) => messages),
        dmConversationListProvider.overrideWith(
          (ref) => Stream.value([
            const DmConversation(
              id: _convoId,
              otherUserId: _other,
              otherUserName: 'Bob',
            ),
          ]),
        ),
        directMessageRepositoryProvider.overrideWithValue(repo),
        directMessageRemoteDataSourceProvider.overrideWithValue(dataSource),
        crashReporterProvider.overrideWithValue(crashReporter),
      ],
      child: const MaterialApp(home: DmThreadPage(conversationId: _convoId)),
    ),
  );

  // A plain pump, not pumpAndSettle — the typing-indicator's real
  // RealtimeChannel.subscribe() never settles under the test project's
  // dummy URL, same reasoning as chat_page_test.dart's harness.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  return _Harness(repo: repo, dataSource: dataSource);
}

void main() {
  setUpAll(initTestSupabase);

  group('DmThreadPage', () {
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
      expect(find.text('Say hello to Bob!'), findsOneWidget);
    });

    testWidgets('shows the other participant\'s name in the app bar', (
      tester,
    ) async {
      await _pump(tester, messages: Stream.value(const []));
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Direct message'), findsOneWidget);
    });

    testWidgets('renders messages from both participants', (tester) async {
      await _pump(
        tester,
        messages: Stream.value([
          _msg(id: 'm1', senderId: _other, senderName: 'Bob', content: 'hi'),
          _msg(id: 'm2', senderId: _me, content: 'hello back'),
        ]),
      );
      expect(find.text('hi'), findsOneWidget);
      expect(find.text('hello back'), findsOneWidget);
    });

    testWidgets('sends a typed message and clears the input', (tester) async {
      final h = await _pump(tester, messages: Stream.value(const []));
      when(
        () => h.repo.sendMessage(
          conversationId: any(named: 'conversationId'),
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

      verify(
        () => h.repo.sendMessage(
          conversationId: _convoId,
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
        () => h.repo.sendMessage(
          conversationId: any(named: 'conversationId'),
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

    testWidgets('long-pressing your own message opens the read-receipt sheet', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        messages: Stream.value([
          _msg(id: 'm1', senderId: _me, content: 'seen?'),
        ]),
      );
      when(() => h.repo.getReadReceipts('m1')).thenAnswer(
        (_) async => Right([
          MessageReadReceipt(
            userId: _other,
            displayName: 'Bob',
            readAt: DateTime.utc(2026, 6, 1, 11),
          ),
        ]),
      );

      await tester.longPress(find.text('seen?'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Message info'), findsOneWidget);
    });

    testWidgets('blocking the other participant shows the blocked banner '
        'and hides the composer', (tester) async {
      final h = await _pump(tester, messages: Stream.value(const []));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Block Bob'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Confirm dialog.
      await tester.tap(find.widgetWithText(TextButton, 'Block'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => h.repo.blockUser(_other)).called(1);
      expect(find.text('You blocked Bob.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a conversation already blocked shows the banner on open', (
      tester,
    ) async {
      await _pump(tester, messages: Stream.value(const []), blockedByMe: true);

      expect(find.text('You blocked Bob.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });
}
