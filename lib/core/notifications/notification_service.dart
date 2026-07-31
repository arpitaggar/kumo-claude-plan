import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/router.dart';

/// Wraps [FlutterLocalNotificationsPlugin] for the single notification kind
/// this app currently shows: a new chat message. Delivery only happens while
/// the app process is alive (foreground, or briefly backgrounded) — it is
/// not OS-level push and will not reach a fully-killed app.
class NotificationService {
  NotificationService(this._prefs) : _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'chat_messages';
  static const _channelName = 'Chat Messages';
  static const _channelDescription = 'New messages in your trip chats';
  static const _permissionRequestedKey = 'notif_permission_requested';

  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _prefs;
  int _nextId = 0;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
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
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showChatMessageNotification({
    required String tripId,
    required String tripTitle,
    required String senderName,
    required String body,
  }) =>
      _plugin.show(
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
        payload: tripId,
      );

  void _onTap(NotificationResponse response) {
    final tripId = response.payload;
    if (tripId == null) {
      return;
    }
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      return;
    }
    GoRouter.of(context).go('/trip/$tripId/chat');
  }
}
