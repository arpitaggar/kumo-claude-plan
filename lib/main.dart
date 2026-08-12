import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/brand.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'config/theme_provider.dart';
import 'core/network/supabase_client.dart';
import 'core/notifications/push_config.dart';
import 'core/notifications/push_message_handler.dart';
import 'core/utils/logger.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/chat/presentation/providers/chat_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await KumoSupabaseClient.initialize();
    AppLogger.info('Supabase initialized');
  } catch (e, st) {
    // Rethrowing here (the old behavior) left runApp() never called — no
    // widget tree ever gets built, so the native launch-screen placeholder
    // (see flutter_native_splash's styles.xml comment: "Automatically
    // removed when the Flutter engine draws its first frame") just sits on
    // screen forever with zero indication anything went wrong. The
    // exception is right there in logcat, but nobody's tailing logcat
    // while staring at a phone that looks hung. Render it instead.
    AppLogger.critical(
      'Failed to initialize Supabase',
      error: e,
      stackTrace: st,
    );
    runApp(StartupErrorApp(error: e));
    return;
  }

  final isIos = defaultTargetPlatform == TargetPlatform.iOS;
  if (defaultTargetPlatform == TargetPlatform.android ||
      (isIos && kIosPushReady)) {
    try {
      await Firebase.initializeApp();
      if (isIos) {
        // iOS shows push via a native APNs alert (see
        // send-message-push/index.ts), not flutter_local_notifications, so
        // there's no local-notification tap callback to hook into — tap
        // navigation has to go through FCM's own open-app events instead.
        FirebaseMessaging.onMessageOpenedApp.listen(handleIosPushTap);
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null) {
          handleIosPushTap(initialMessage);
        }
      } else {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      }
      AppLogger.info('Firebase initialized');
    } catch (e, st) {
      AppLogger.warning('Firebase init failed: $e\n$st');
    }
  }

  final sharedPreferences = await SharedPreferences.getInstance();
  final lastInboxVisitMs = sharedPreferences.getInt('inbox_last_visit_ms') ?? 0;

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        inboxLastVisitProvider.overrideWith((_) => lastInboxVisitMs),
      ],
      child: const KumoApp(),
    ),
  );
}

/// Shown instead of the normal app when startup fails before `runApp()`
/// would otherwise ever be called (currently only `KumoSupabaseClient
/// .initialize()` failing, e.g. missing `--dart-define` config) — so a
/// startup failure is visible on the device instead of looking identical
/// to a hang on the native launch screen.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Kumo failed to start',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  // Only show the raw exception in debug/profile builds — a
                  // release build's failure screen shouldn't print internal
                  // details (e.g. the Supabase project URL) to anyone with
                  // physical access to the device.
                  kReleaseMode ? 'Please contact support.' : '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class KumoApp extends ConsumerWidget {
  const KumoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final kumoTheme = ref.watch(effectiveThemeProvider);

    return MaterialApp.router(
      title: Brand.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.all[kumoTheme],
      routerConfig: router,
    );
  }
}
