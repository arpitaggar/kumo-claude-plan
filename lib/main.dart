import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/router.dart';
import 'config/theme.dart';
import 'core/network/supabase_client.dart';
import 'core/utils/logger.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

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

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const KumoApp(),
    ),
  );
}

class KumoApp extends ConsumerWidget {
  const KumoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Kumo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
