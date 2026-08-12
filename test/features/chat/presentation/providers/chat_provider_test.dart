import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kumo_claude/core/notifications/notification_providers.dart';
import 'package:kumo_claude/core/notifications/notification_service.dart';
import 'package:kumo_claude/features/auth/domain/repositories/auth_repository.dart';
import 'package:kumo_claude/features/auth/domain/entities/user.dart';
import 'package:kumo_claude/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/login_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/logout_usecase.dart';
import 'package:kumo_claude/features/auth/domain/usecases/signup_usecase.dart';
import 'package:kumo_claude/features/auth/presentation/providers/auth_provider.dart';
import 'package:kumo_claude/features/chat/domain/entities/message.dart';
import 'package:kumo_claude/features/chat/domain/entities/message_attachment.dart';
import 'package:kumo_claude/features/chat/presentation/providers/chat_provider.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/create_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/delete_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/fetch_itineraries_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/update_itinerary_usecase.dart';
import 'package:kumo_claude/features/itinerary/presentation/providers/itinerary_provider.dart';
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

class MockFetchItinerariesUseCase extends Mock
    implements FetchItinerariesUseCase {}

class MockCreateItineraryUseCase extends Mock
    implements CreateItineraryUseCase {}

class MockUpdateItineraryUseCase extends Mock
    implements UpdateItineraryUseCase {}

class MockDeleteItineraryUseCase extends Mock
    implements DeleteItineraryUseCase {}

class MockNotificationService extends Mock implements NotificationService {}

const _tripId = 'trip-1';
const _tripTitle = 'Paris Trip';
const _me = 'user-me';
const _other = 'user-other';

TravelItinerary _trip() => TravelItinerary(
  id: _tripId,
  title: _tripTitle,
  ownerId: _me,
  startDate: DateTime(2026, 10),
  endDate: DateTime(2026, 10, 7),
  totalBudget: 1000,
  currencyCode: 'EUR',
  members: const [],
  items: const [],
  expenseSummary: const ExpenseSummary(
    totalSpent: 0,
    spentByCategory: {},
    memberBalances: {},
  ),
  createdAt: DateTime(2026, 6),
  updatedAt: DateTime(2026, 6),
);

Message _msg({
  required String id,
  required String senderId,
  String content = 'hello',
  List<MessageAttachment> attachments = const [],
}) => Message(
  id: id,
  itineraryId: _tripId,
  senderId: senderId,
  senderName: 'Someone',
  content: content,
  createdAt: DateTime.now(),
  attachments: attachments,
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

/// Builds a [ProviderContainer] wired so that:
///  - the authenticated user is [_me]
///  - the trip list contains a single trip ([_trip])
///  - `chatStreamProvider(_tripId)` is driven by the returned [StreamController]
///  - `showChatMessageNotification` calls land on the returned mock
Future<
  ({
    ProviderContainer container,
    StreamController<List<Message>> controller,
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

  final fetchUseCase = MockFetchItinerariesUseCase();
  when(() => fetchUseCase(any())).thenAnswer((_) async => Right([_trip()]));
  final itineraryNotifier = ItineraryListNotifier(
    fetchUseCase: fetchUseCase,
    createUseCase: MockCreateItineraryUseCase(),
    updateUseCase: MockUpdateItineraryUseCase(),
    deleteUseCase: MockDeleteItineraryUseCase(),
  );

  final notificationService = MockNotificationService();
  when(
    () => notificationService.showChatMessageNotification(
      tripId: any(named: 'tripId'),
      tripTitle: any(named: 'tripTitle'),
      senderName: any(named: 'senderName'),
      body: any(named: 'body'),
    ),
  ).thenAnswer((_) async {});

  // Ownership is handed to the caller, which closes it via
  // `h.controller.close()` at the end of every test using this harness; the
  // lint can't see across that function boundary.
  // ignore: close_sinks
  final controller = StreamController<List<Message>>();

  // userProfileProvider/notificationPreferencesProvider are `.autoDispose` —
  // pin them alive for the container's lifetime so a later `ref.read` inside
  // `_maybeNotify` can't race a disposal/recreation cycle and see a fresh
  // AsyncLoading (with a null `.value`) instead of the settled override data.
  //
  // Settle every async provider this scenario depends on before the test
  // starts pushing stream events, so `_maybeNotify`'s synchronous `ref.read`
  // calls see their final values rather than initial loading states.
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
            itineraryListProvider.overrideWith((ref) => itineraryNotifier),
            chatStreamProvider(
              _tripId,
            ).overrideWith((ref) => controller.stream),
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
  await itineraryNotifier.loadItineraries(_me);
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
  StreamController<List<Message>> controller,
  List<Message> messages,
) async {
  controller.add(messages);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  setUpAll(initTestSupabase);

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  const chatPushEnabled = NotificationPreference(
    channel: NotifChannel.push,
    category: NotifCategory.chatMessages,
    enabled: true,
  );
  const chatPushDisabled = NotificationPreference(
    channel: NotifChannel.push,
    category: NotifCategory.chatMessages,
    enabled: false,
  );

  group('chatMessageWatcherProvider / _maybeNotify', () {
    test('notifies for a new message from someone else', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final h = await _buildHarness(
        prefs: [chatPushEnabled],
        profile: _profile(previewEnabled: true),
      );
      h.container.read(chatMessageWatcherProvider);

      await _emit(h.controller, [_msg(id: 'm1', senderId: _other)]);
      await _emit(h.controller, [
        _msg(id: 'm1', senderId: _other),
        _msg(id: 'm2', senderId: _other, content: 'second message'),
      ]);

      verify(
        () => h.notificationService.showChatMessageNotification(
          tripId: _tripId,
          tripTitle: _tripTitle,
          senderName: any(named: 'senderName'),
          body: 'second message',
        ),
      ).called(1);

      await h.controller.close();
      h.container.dispose();
    });

    test('does not notify for a message the current user sent', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final h = await _buildHarness(
        prefs: [chatPushEnabled],
        profile: _profile(previewEnabled: true),
      );
      h.container.read(chatMessageWatcherProvider);

      await _emit(h.controller, [_msg(id: 'm1', senderId: _me)]);
      await _emit(h.controller, [
        _msg(id: 'm1', senderId: _me),
        _msg(id: 'm2', senderId: _me, content: 'my own message'),
      ]);

      verifyNever(
        () => h.notificationService.showChatMessageNotification(
          tripId: any(named: 'tripId'),
          tripTitle: any(named: 'tripTitle'),
          senderName: any(named: 'senderName'),
          body: any(named: 'body'),
        ),
      );

      await h.controller.close();
      h.container.dispose();
    });

    test('does not notify when the trip chat is already open', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final h = await _buildHarness(
        prefs: [chatPushEnabled],
        profile: _profile(previewEnabled: true),
      );
      h.container.read(activeChatIdProvider.notifier).state = _tripId;
      h.container.read(chatMessageWatcherProvider);

      await _emit(h.controller, [_msg(id: 'm1', senderId: _other)]);
      await _emit(h.controller, [
        _msg(id: 'm1', senderId: _other),
        _msg(id: 'm2', senderId: _other),
      ]);

      verifyNever(
        () => h.notificationService.showChatMessageNotification(
          tripId: any(named: 'tripId'),
          tripTitle: any(named: 'tripTitle'),
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
          prefs: [chatPushDisabled],
          profile: _profile(previewEnabled: true),
        );
        h.container.read(chatMessageWatcherProvider);

        await _emit(h.controller, [_msg(id: 'm1', senderId: _other)]);
        await _emit(h.controller, [
          _msg(id: 'm1', senderId: _other),
          _msg(id: 'm2', senderId: _other),
        ]);

        verifyNever(
          () => h.notificationService.showChatMessageNotification(
            tripId: any(named: 'tripId'),
            tripTitle: any(named: 'tripTitle'),
            senderName: any(named: 'senderName'),
            body: any(named: 'body'),
          ),
        );

        await h.controller.close();
        h.container.dispose();
      },
    );

    test(
      'defaults to enabled when no chat_messages preference row exists',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        final h = await _buildHarness(
          // prefs omitted — defaults to `const []`, i.e. no row loaded yet
          profile: _profile(previewEnabled: true),
        );
        h.container.read(chatMessageWatcherProvider);

        await _emit(h.controller, [_msg(id: 'm1', senderId: _other)]);
        await _emit(h.controller, [
          _msg(id: 'm1', senderId: _other),
          _msg(id: 'm2', senderId: _other, content: 'default enabled'),
        ]);

        verify(
          () => h.notificationService.showChatMessageNotification(
            tripId: _tripId,
            tripTitle: _tripTitle,
            senderName: any(named: 'senderName'),
            body: 'default enabled',
          ),
        ).called(1);

        await h.controller.close();
        h.container.dispose();
      },
    );

    test('hides the message body when preview is disabled', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final h = await _buildHarness(
        prefs: [chatPushEnabled],
        profile: _profile(previewEnabled: false),
      );
      h.container.read(chatMessageWatcherProvider);

      await _emit(h.controller, [_msg(id: 'm1', senderId: _other)]);
      await _emit(h.controller, [
        _msg(id: 'm1', senderId: _other),
        _msg(id: 'm2', senderId: _other, content: 'super secret content'),
      ]);

      verify(
        () => h.notificationService.showChatMessageNotification(
          tripId: _tripId,
          tripTitle: _tripTitle,
          senderName: any(named: 'senderName'),
          body: 'New message',
        ),
      ).called(1);

      await h.controller.close();
      h.container.dispose();
    });

    test('shows a photo placeholder for an image-only message', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final h = await _buildHarness(
        prefs: [chatPushEnabled],
        profile: _profile(previewEnabled: true),
      );
      h.container.read(chatMessageWatcherProvider);

      await _emit(h.controller, [_msg(id: 'm1', senderId: _other)]);
      await _emit(h.controller, [
        _msg(id: 'm1', senderId: _other),
        _msg(
          id: 'm2',
          senderId: _other,
          content: '',
          attachments: const [
            MessageAttachment(
              id: 'a1',
              kind: AttachmentKind.image,
              url: 'https://example.com/a.jpg',
              fileName: 'a.jpg',
              mimeType: 'image/jpeg',
              sizeBytes: 100,
            ),
          ],
        ),
      ]);

      verify(
        () => h.notificationService.showChatMessageNotification(
          tripId: _tripId,
          tripTitle: _tripTitle,
          senderName: any(named: 'senderName'),
          body: '📷 Photo',
        ),
      ).called(1);

      await h.controller.close();
      h.container.dispose();
    });

    test(
      'shows a file placeholder for a non-image attachment-only message',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        final h = await _buildHarness(
          prefs: [chatPushEnabled],
          profile: _profile(previewEnabled: true),
        );
        h.container.read(chatMessageWatcherProvider);

        await _emit(h.controller, [_msg(id: 'm1', senderId: _other)]);
        await _emit(h.controller, [
          _msg(id: 'm1', senderId: _other),
          _msg(
            id: 'm2',
            senderId: _other,
            content: '',
            attachments: const [
              MessageAttachment(
                id: 'a1',
                kind: AttachmentKind.file,
                url: 'https://example.com/a.pdf',
                fileName: 'a.pdf',
                mimeType: 'application/pdf',
                sizeBytes: 100,
              ),
            ],
          ),
        ]);

        verify(
          () => h.notificationService.showChatMessageNotification(
            tripId: _tripId,
            tripTitle: _tripTitle,
            senderName: any(named: 'senderName'),
            body: '📎 Attachment',
          ),
        ).called(1);

        await h.controller.close();
        h.container.dispose();
      },
    );

    test(
      'on Android, suppresses the notification unless the app is resumed',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );

        final h = await _buildHarness(
          prefs: [chatPushEnabled],
          profile: _profile(previewEnabled: true),
        );
        h.container.read(chatMessageWatcherProvider);

        await _emit(h.controller, [_msg(id: 'm1', senderId: _other)]);
        await _emit(h.controller, [
          _msg(id: 'm1', senderId: _other),
          _msg(id: 'm2', senderId: _other),
        ]);

        verifyNever(
          () => h.notificationService.showChatMessageNotification(
            tripId: any(named: 'tripId'),
            tripTitle: any(named: 'tripTitle'),
            senderName: any(named: 'senderName'),
            body: any(named: 'body'),
          ),
        );

        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _emit(h.controller, [
          _msg(id: 'm1', senderId: _other),
          _msg(id: 'm2', senderId: _other),
          _msg(id: 'm3', senderId: _other, content: 'now resumed'),
        ]);

        verify(
          () => h.notificationService.showChatMessageNotification(
            tripId: _tripId,
            tripTitle: _tripTitle,
            senderName: any(named: 'senderName'),
            body: 'now resumed',
          ),
        ).called(1);

        await h.controller.close();
        h.container.dispose();
      },
    );
  });
}
