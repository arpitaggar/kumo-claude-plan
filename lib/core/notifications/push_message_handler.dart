import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../config/router.dart';

const _channelId = 'chat_messages';
const _channelName = 'Chat Messages';
const _channelDescription = 'New messages in your trip chats';

/// Runs in a separate background isolate when a data message arrives while
/// the app is backgrounded or fully killed (Android only for now — this is
/// registered from `main.dart` via `FirebaseMessaging.onBackgroundMessage`).
///
/// A fresh isolate shares none of the running app's state — no Riverpod
/// container, no existing Firebase/plugin instances — so everything needed
/// is re-created here from the message's data payload alone. The payload is
/// built server-side (`supabase/functions/send-message-push`), which already
/// applied the recipient's notification/preview preferences, so this handler
/// just displays exactly what it's given.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final tripId = message.data['tripId'] as String?;
  final tripTitle = message.data['tripTitle'] as String?;
  final senderName = message.data['senderName'] as String?;
  final body = message.data['body'] as String?;
  if (tripId == null || body == null) {
    return;
  }

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
  await plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );

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
    payload: tripId,
  );
}

/// Navigates to the relevant chat when the user taps an iOS push
/// notification — whether that opened the app from backgrounded
/// (`FirebaseMessaging.onMessageOpenedApp`) or fully killed
/// (`FirebaseMessaging.instance.getInitialMessage`). Android doesn't need
/// this: its notifications are always shown via flutter_local_notifications,
/// whose own tap callback (`NotificationService._onTap`) already covers both
/// cases.
void handleIosPushTap(RemoteMessage message) {
  final tripId = message.data['tripId'] as String?;
  if (tripId == null) {
    return;
  }
  final context = rootNavigatorKey.currentContext;
  if (context == null) {
    return;
  }
  GoRouter.of(context).go('/trip/$tripId/chat');
}
