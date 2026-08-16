import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/notifications/notification_providers.dart';
import 'package:kumo_claude/core/notifications/notification_service.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/direct_messages/domain/entities/dm_conversation.dart';
import 'package:kumo_claude/features/direct_messages/presentation/providers/direct_message_provider.dart';
import 'package:kumo_claude/features/profile/domain/entities/notification_preference.dart';
import 'package:kumo_claude/features/profile/domain/entities/user_profile.dart';
import 'package:kumo_claude/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockSignupUseCase extends Mock implements SignupUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

class MockNotificationService extends Mock implements NotificationService {}

const _convoId = 'conv-1';
const _me = 'user-me';
const _other = 'user-other';

DmConversation _convo({
  DateTime? lastMessageAt,
  String? lastMessageSenderId,
  String? preview = 'hello',
}) => DmConversation(
  id: _convoId,
  otherUserId: _other,
  otherUserName: 'Bob',
  lastMessageAt: lastMessageAt,
  lastMessagePreview: preview,
  lastMessageSenderId: lastMessageSenderId,
);

UserProfile _profile({required bool previewEnabled}) => UserProfile(
  id: _me,
  email: 'me@example.com',
  displayName: 'Me',
  isSearchable: true,
  profileVisibility: 'public',
  contactVisibility: 'collaborators_only',
  unitsPreference: 'metric',
  travelPreferenceTags: const [],
  updatedAt: DateTime(2026, 6),
  pushMessagePreviewEnabled: previewEnabled,
);

/// Mirrors chat_provider_test.dart's `_buildHarness` shape — DM's watcher
/// only depends on `dmConversationListProvider` (one denormalized stream),
/// not a per-conversation-family fan-out, so this harness is simpler than
/// chat's (no itinerary list / no per-trip streams needed).
Future<
  ({
    ProviderContainer container,
    StreamController<List<DmConversation>> controller,
    MockNotificationService notificationService,
  })
>
_buildHarness({
  List<NotificationPreference> prefs = const [],
  UserProfile? profile,
}) async {
  final authRepo = MockAuthRepository();
  when(authRepo.getCurrentUser).thenAnswer(
    (_) async => Right(
      User(id: _me, email: 'me@example.com', createdAt: DateTime(2026)),
    ),
  );

  final notificationService = MockNotificationService();
  when(
    () => notificationService.showDmMessageNotification(
      conversationId: any(named: 'conversationId'),
      senderName: any(named: 'senderName'),
      body: any(named: 'body'),
    ),
  ).thenAnswer((_) async {});

  // ignore: close_sinks
  final controller = StreamController<List<DmConversation>>();

  final container =
      ProviderContainer(
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
            dmConversationListProvider.overrideWith((ref) => controller.stream),
            notificationPreferencesProvider.overrideWith((ref) async => prefs),
            userProfileProvider.overrideWith((ref) async => profile),
            notificationServiceProvider.overrideWith(
              (ref) async => notificationService,
            ),
          ],
        )
        ..listen(userProfileProvider, (_, _) {})
        ..listen(notificationPreferencesProvider, (_, _) {})
        ..read(authNotifierProvider);
  await container.read(notificationServiceProvider.future);
  await container.read(notificationPreferencesProvider.future);
  await container.read(userProfileProvider.future);
  await Future<void>.delayed(Duration.zero);

  return (
    container: container,
    controller: controller,
    notificationService: notificationService,
  );
}

Future<void> _emit(
  StreamController<List<DmConversation>> controller,
  List<DmConversation> conversations,
) async {
  controller.add(conversations);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  setUpAll(initTestSupabase);

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  const dmPushEnabled = NotificationPreference(
    channel: NotifChannel.push,
    category: NotifCategory.chatMessages,
    enabled: true,
  );
  const dmPushDisabled = NotificationPreference(
    channel: NotifChannel.push,
    category: NotifCategory.chatMessages,
    enabled: false,
  );

  group('dmMessageWatcherProvider', () {
    test(
      'notifies when a conversation gets a message from someone else',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        final h = await _buildHarness(
          prefs: [dmPushEnabled],
          profile: _profile(previewEnabled: true),
        );
        h.container.read(dmMessageWatcherProvider);

        await _emit(h.controller, [
          _convo(
            lastMessageAt: DateTime.fromMillisecondsSinceEpoch(1000),
            lastMessageSenderId: _other,
          ),
        ]);
        await _emit(h.controller, [
          _convo(
            lastMessageAt: DateTime.fromMillisecondsSinceEpoch(2000),
            lastMessageSenderId: _other,
            preview: 'second message',
          ),
        ]);

        verify(
          () => h.notificationService.showDmMessageNotification(
            conversationId: _convoId,
            senderName: 'Bob',
            body: 'second message',
          ),
        ).called(1);

        await h.controller.close();
        h.container.dispose();
      },
    );

    test('does not notify for the caller\'s own outgoing message', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final h = await _buildHarness(
        prefs: [dmPushEnabled],
        profile: _profile(previewEnabled: true),
      );
      h.container.read(dmMessageWatcherProvider);

      await _emit(h.controller, [
        _convo(
          lastMessageAt: DateTime.fromMillisecondsSinceEpoch(1000),
          lastMessageSenderId: _me,
        ),
      ]);
      await _emit(h.controller, [
        _convo(
          lastMessageAt: DateTime.fromMillisecondsSinceEpoch(2000),
          lastMessageSenderId: _me,
        ),
      ]);

      verifyNever(
        () => h.notificationService.showDmMessageNotification(
          conversationId: any(named: 'conversationId'),
          senderName: any(named: 'senderName'),
          body: any(named: 'body'),
        ),
      );

      await h.controller.close();
      h.container.dispose();
    });

    test('does not notify when the conversation is already open', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final h = await _buildHarness(
        prefs: [dmPushEnabled],
        profile: _profile(previewEnabled: true),
      );
      h.container.read(activeDmConversationIdProvider.notifier).state =
          _convoId;
      h.container.read(dmMessageWatcherProvider);

      await _emit(h.controller, [
        _convo(
          lastMessageAt: DateTime.fromMillisecondsSinceEpoch(1000),
          lastMessageSenderId: _other,
        ),
      ]);
      await _emit(h.controller, [
        _convo(
          lastMessageAt: DateTime.fromMillisecondsSinceEpoch(2000),
          lastMessageSenderId: _other,
        ),
      ]);

      verifyNever(
        () => h.notificationService.showDmMessageNotification(
          conversationId: any(named: 'conversationId'),
          senderName: any(named: 'senderName'),
          body: any(named: 'body'),
        ),
      );

      await h.controller.close();
      h.container.dispose();
    });

    test(
      'does not notify when the chat_messages push preference is disabled',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        final h = await _buildHarness(
          prefs: [dmPushDisabled],
          profile: _profile(previewEnabled: true),
        );
        h.container.read(dmMessageWatcherProvider);

        await _emit(h.controller, [
          _convo(
            lastMessageAt: DateTime.fromMillisecondsSinceEpoch(1000),
            lastMessageSenderId: _other,
          ),
        ]);
        await _emit(h.controller, [
          _convo(
            lastMessageAt: DateTime.fromMillisecondsSinceEpoch(2000),
            lastMessageSenderId: _other,
          ),
        ]);

        verifyNever(
          () => h.notificationService.showDmMessageNotification(
            conversationId: any(named: 'conversationId'),
            senderName: any(named: 'senderName'),
            body: any(named: 'body'),
          ),
        );

        await h.controller.close();
        h.container.dispose();
      },
    );

    test('hides the message body when preview is disabled', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final h = await _buildHarness(
        prefs: [dmPushEnabled],
        profile: _profile(previewEnabled: false),
      );
      h.container.read(dmMessageWatcherProvider);

      await _emit(h.controller, [
        _convo(
          lastMessageAt: DateTime.fromMillisecondsSinceEpoch(1000),
          lastMessageSenderId: _other,
        ),
      ]);
      await _emit(h.controller, [
        _convo(
          lastMessageAt: DateTime.fromMillisecondsSinceEpoch(2000),
          lastMessageSenderId: _other,
          preview: 'super secret content',
        ),
      ]);

      verify(
        () => h.notificationService.showDmMessageNotification(
          conversationId: _convoId,
          senderName: 'Bob',
          body: 'New message',
        ),
      ).called(1);

      await h.controller.close();
      h.container.dispose();
    });

    test(
      'on Android, suppresses the notification unless the app is resumed',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );

        final h = await _buildHarness(
          prefs: [dmPushEnabled],
          profile: _profile(previewEnabled: true),
        );
        h.container.read(dmMessageWatcherProvider);

        await _emit(h.controller, [
          _convo(
            lastMessageAt: DateTime.fromMillisecondsSinceEpoch(1000),
            lastMessageSenderId: _other,
          ),
        ]);
        await _emit(h.controller, [
          _convo(
            lastMessageAt: DateTime.fromMillisecondsSinceEpoch(2000),
            lastMessageSenderId: _other,
          ),
        ]);

        verifyNever(
          () => h.notificationService.showDmMessageNotification(
            conversationId: any(named: 'conversationId'),
            senderName: any(named: 'senderName'),
            body: any(named: 'body'),
          ),
        );

        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _emit(h.controller, [
          _convo(
            lastMessageAt: DateTime.fromMillisecondsSinceEpoch(3000),
            lastMessageSenderId: _other,
            preview: 'now resumed',
          ),
        ]);

        verify(
          () => h.notificationService.showDmMessageNotification(
            conversationId: _convoId,
            senderName: 'Bob',
            body: 'now resumed',
          ),
        ).called(1);

        await h.controller.close();
        h.container.dispose();
      },
    );
  });
}
