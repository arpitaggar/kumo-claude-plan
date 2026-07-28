import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import 'notification_service.dart';

/// Created and initialized once per app lifetime. A `FutureProvider` (rather
/// than plumbing an explicit init call through `main.dart`'s `ProviderScope`)
/// keeps the async plugin setup self-contained; consumers that need
/// synchronous access (e.g. the chat-message watcher) read `.value`, which is
/// populated almost immediately after app start and simply skipped if a
/// message somehow arrives before that.
final notificationServiceProvider = FutureProvider<NotificationService>(
  (ref) async {
    final service = NotificationService(ref.watch(sharedPreferencesProvider));
    await service.initialize();
    return service;
  },
);
