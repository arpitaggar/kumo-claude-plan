import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../config/router.dart';

const _channelId = 'chat_messages';
const _channelName = 'Chat Messages';
const _channelDescription = 'New messages in your trip chats';
const _socialChannelId = 'social_activity';
const _socialChannelName = 'Activity';
const _socialChannelDescription =
    'Likes, follows, and new posts from people you follow';

/// Runs in a separate background isolate when a data message arrives while
/// the app is backgrounded or fully killed (Android only for now — this is
/// registered from `main.dart` via `FirebaseMessaging.onBackgroundMessage`).
///
/// A fresh isolate shares none of the running app's state — no Riverpod
/// container, no existing Firebase/plugin instances — so everything needed
/// is re-created here from the message's data payload alone. The payload is
/// built server-side (`send-message-push`/`send-social-push`), which already
/// applied the recipient's notification/preview preferences, so this handler
/// just displays exactly what it's given. `data['kind']` (`'chat'` when
/// absent, for older-payload compatibility, or `'social'`) picks which of
/// the two notification kinds this is.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  // Channels persist at the OS level once created, but re-creating here is
  // cheap and idempotent — guards against this being the very first
  // notification the app ever shows (background isolate, before the app's
  // own `NotificationService.initialize()` has ever run in the foreground).
  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    ),
  );
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      _socialChannelId,
      _socialChannelName,
      description: _socialChannelDescription,
      importance: Importance.high,
    ),
  );

  if (message.data['kind'] == 'social') {
    await _showSocialBackgroundNotification(plugin, message);
  } else {
    await _showChatBackgroundNotification(plugin, message);
  }
}

Future<void> _showChatBackgroundNotification(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  final tripId = message.data['tripId'] as String?;
  final tripTitle = message.data['tripTitle'] as String?;
  final senderName = message.data['senderName'] as String?;
  final body = message.data['body'] as String?;
  if (tripId == null || body == null) {
    return;
  }

  await plugin.show(
    id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title: tripTitle != null ? '$senderName · $tripTitle' : senderName,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: 'chat:$tripId',
  );
}

Future<void> _showSocialBackgroundNotification(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  final actorId = message.data['actorId'] as String?;
  final title = message.data['title'] as String?;
  final body = message.data['body'] as String?;
  if (actorId == null || title == null || body == null) {
    return;
  }

  await plugin.show(
    id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _socialChannelId,
        _socialChannelName,
        channelDescription: _socialChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: 'social:$actorId',
  );
}

/// Navigates to the relevant screen when the user taps an iOS push
/// notification — whether that opened the app from backgrounded
/// (`FirebaseMessaging.onMessageOpenedApp`) or fully killed
/// (`FirebaseMessaging.instance.getInitialMessage`). Android doesn't need
/// this: its notifications are always shown via flutter_local_notifications,
/// whose own tap callback (`NotificationService._onTap`) already covers both
/// cases. `data['kind']` picks chat vs. social, same as the background
/// handler above.
void handleIosPushTap(RemoteMessage message) {
  final context = rootNavigatorKey.currentContext;
  if (context == null) {
    return;
  }

  if (message.data['kind'] == 'social') {
    final actorId = message.data['actorId'] as String?;
    if (actorId == null) {
      return;
    }
    GoRouter.of(context).go('/u/$actorId');
    return;
  }

  final tripId = message.data['tripId'] as String?;
  if (tripId == null) {
    return;
  }
  GoRouter.of(context).go('/trip/$tripId/chat');
}
