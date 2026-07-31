import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    await dotenv.load();
    AppLogger.info('Environment variables loaded');
  } catch (e) {
    AppLogger.warning('Could not load .env file: $e');
  }

  try {
    await KumoSupabaseClient.initialize();
    AppLogger.info('Supabase initialized');
  } catch (e, st) {
    AppLogger.critical('Failed to initialize Supabase', error: e, stackTrace: st);
    rethrow;
  }

  final isIos = defaultTargetPlatform == TargetPlatform.iOS;
  if (defaultTargetPlatform == TargetPlatform.android || (isIos && kIosPushReady)) {
    try {
      await Firebase.initializeApp();
      if (isIos) {
        // iOS shows push via a native APNs alert (see
        // send-message-push/index.ts), not flutter_local_notifications, so
        // there's no local-notification tap callback to hook into — tap
        // navigation has to go through FCM's own open-app events instead.
        FirebaseMessaging.onMessageOpenedApp.listen(handleIosPushTap);
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          handleIosPushTap(initialMessage);
        }
      } else {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }
      AppLogger.info('Firebase initialized');
    } catch (e, st) {
      AppLogger.warning('Firebase init failed: $e\n$st');
    }
  }

  final sharedPreferences = await SharedPreferences.getInstance();
  final lastInboxVisitMs =
      sharedPreferences.getInt('inbox_last_visit_ms') ?? 0;

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

class KumoApp extends ConsumerWidget {
  const KumoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router     = ref.watch(routerProvider);
    final kumoTheme  = ref.watch(themeProvider);

    return MaterialApp.router(
      title: Brand.appName,
      debugShowCheckedModeBanner: false,
      theme: switch (kumoTheme) {
        KumoTheme.goldenHour       => AppTheme.goldenHour,
        KumoTheme.deepVoyage       => AppTheme.deepVoyage,
        KumoTheme.cherryBlossom    => AppTheme.light,
        KumoTheme.synthwaveTokyo   => AppTheme.synthwaveTokyo,
        KumoTheme.whiteAndCharcoal => AppTheme.whiteAndCharcoal,
        KumoTheme.warmOatLightBlue => AppTheme.warmOatLightBlue,
      },
      routerConfig: router,
    );
  }
}
