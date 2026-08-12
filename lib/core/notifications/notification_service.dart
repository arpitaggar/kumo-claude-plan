import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_tap_events.dart';

/// Wraps [FlutterLocalNotificationsPlugin] for the two notification kinds
/// this app shows: a new chat message, and social activity (likes, follows,
/// new posts from people you follow). Delivery only happens while the app
/// process is alive (foreground, or briefly backgrounded) — it is not
/// OS-level push and will not reach a fully-killed app.
///
/// Every notification's `payload` is `'<kind>:<id>'` (`'chat:<tripId>'` or
/// `'social:<actorId>'`) so [_onTap] can route a tap to the right place
/// without needing separate tap callbacks per kind.
class NotificationService {
  NotificationService(this._prefs)
    : _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'chat_messages';
  static const _channelName = 'Chat Messages';
  static const _channelDescription = 'New messages in your trip chats';
  static const _socialChannelId = 'social_activity';
  static const _socialChannelName = 'Activity';
  static const _socialChannelDescription =
      'Likes, follows, and new posts from people you follow';
  static const _permissionRequestedKey = 'notif_permission_requested';

  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _prefs;
  int _nextId = 0;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    // Permission is requested explicitly and later (see requestPermissionOnce),
    // not immediately on init — the user shouldn't be prompted before login.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onTap,
    );

    final androidPlugin = _plugin
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

    // `onDidReceiveNotificationResponse` above only covers the app already
    // being alive (backgrounded) when the notification is tapped. If the app
    // was fully killed and got launched *by* the tap, that launch detail has
    // to be checked explicitly here instead.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails!.notificationResponse;
      if (response != null) {
        _onTap(response);
      }
    }
  }

  /// Requests OS notification permission once per install — safe to call
  /// repeatedly; only the first call after install actually prompts.
  Future<void> requestPermissionOnce() async {
    if (_prefs.getBool(_permissionRequestedKey) ?? false) {
      return;
    }
    await _prefs.setBool(_permissionRequestedKey, true);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showChatMessageNotification({
    required String tripId,
    required String tripTitle,
    required String senderName,
    required String body,
  }) => _plugin.show(
    id: _nextId++,
    title: '$senderName · $tripTitle',
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    payload: 'chat:$tripId',
  );

  Future<void> showSocialActivityNotification({
    required String actorId,
    required String title,
    required String body,
  }) => _plugin.show(
    id: _nextId++,
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
      iOS: DarwinNotificationDetails(),
    ),
    payload: 'social:$actorId',
  );

  void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) {
      return;
    }
    final sepIndex = payload.indexOf(':');
    if (sepIndex == -1) {
      return;
    }
    final kindStr = payload.substring(0, sepIndex);
    final id = payload.substring(sepIndex + 1);
    final kind = switch (kindStr) {
      'chat' => NotificationTapKind.chat,
      'social' => NotificationTapKind.social,
      _ => null,
    };
    if (kind == null) {
      return;
    }
    emitNotificationTap(NotificationTapEvent(kind: kind, id: id));
  }
}
