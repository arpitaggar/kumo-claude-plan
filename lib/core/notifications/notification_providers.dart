import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../network/supabase_client.dart';
import '../utils/logger.dart';
import 'notification_service.dart';
import 'push_config.dart';
import 'push_token_datasource.dart';

final pushTokenDataSourceProvider = Provider<PushTokenDataSource>(
  (ref) => const PushTokenDataSourceImpl(),
);

/// Created and initialized once per app lifetime. A `FutureProvider` (rather
/// than plumbing an explicit init call through `main.dart`'s `ProviderScope`)
/// keeps the async plugin setup self-contained; consumers that need
/// synchronous access (e.g. the chat-message watcher) read `.value`, which is
/// populated almost immediately after app start and simply skipped if a
/// message somehow arrives before that.
final notificationServiceProvider = FutureProvider<NotificationService>((
  ref,
) async {
  final service = NotificationService(ref.watch(sharedPreferencesProvider));
  await service.initialize();
  return service;
});

/// Requests notification permission, fetches the device's FCM token, and
/// keeps it registered in `push_tokens` (including on refresh) for as long
/// as the user is authenticated. iOS only runs this once [kIosPushReady] is
/// flipped on (see `push_config.dart`) — before that, an APNs key isn't
/// configured in Firebase, so `getToken()` would just fail.
///
/// Deliberately does *not* handle `FirebaseMessaging.onMessage` (foreground):
/// every notification this app shows in the foreground goes through
/// `chatMessageWatcherProvider`'s realtime watch instead. Listening to FCM's
/// foreground stream here too would just show the same message a second
/// time. (Tap-opened-from-FCM events *are* handled, but in `main.dart` /
/// `push_message_handler.dart` for iOS specifically — Android's
/// `flutter_local_notifications` tap callback already covers it.)
final fcmTokenSyncProvider = Provider<void>((ref) {
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;
  final isIos = defaultTargetPlatform == TargetPlatform.iOS;
  if (!isAndroid && !(isIos && kIosPushReady)) {
    return;
  }
  final authState = ref.watch(authNotifierProvider);
  if (authState is! AuthAuthenticated) {
    return;
  }

  Future<void> register(String token) async {
    try {
      // Defensive guard against the same session-attachment race already
      // fixed once for AuthRepositoryImpl.getCurrentUser() (2026-08-14):
      // authState reaching AuthAuthenticated only proves the *local*
      // in-memory session was populated at the moment _checkCurrentUser()
      // last read it, not that it's still there (or that this specific
      // request will carry a valid Authorization header) by the time this
      // async chain — permission prompt, then getToken(), then this upsert
      // — actually runs. Confirmed via a real-device integration test
      // (2026-08-17): upsert_push_token's `auth.uid()` resolved to null
      // server-side and the insert failed its NOT NULL constraint on
      // user_id, right after a fresh login. Poll briefly for the live
      // client before giving up, same idiom as that earlier fix, rather
      // than assuming AuthAuthenticated alone is sufficient proof.
      for (var i = 0; i < 10 && KumoSupabaseClient.currentUser == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (KumoSupabaseClient.currentUser == null) {
        AppLogger.warning(
          'Skipping FCM token registration — no live Supabase session '
          'after waiting; onTokenRefresh will retry later.',
        );
        return;
      }
      await ref
          .read(pushTokenDataSourceProvider)
          .upsertPushToken(token: token, platform: isIos ? 'ios' : 'android');
      AppLogger.info('FCM token registered (${token.substring(0, 12)}…)');
    } catch (e, st) {
      AppLogger.critical('FCM token upsert failed', error: e, stackTrace: st);
    }
  }

  FirebaseMessaging.instance
      .requestPermission()
      .then((settings) async {
        AppLogger.info(
          'FCM permission status: ${settings.authorizationStatus}',
        );
        final token = await FirebaseMessaging.instance.getToken();
        if (token == null) {
          AppLogger.warning('FirebaseMessaging.getToken() returned null');
          return;
        }
        await register(token);
      })
      .catchError((Object e, StackTrace st) {
        AppLogger.critical(
          'FCM permission/token fetch failed',
          error: e,
          stackTrace: st,
        );
      });

  final sub = FirebaseMessaging.instance.onTokenRefresh.listen(register);
  ref.onDispose(sub.cancel);
});
