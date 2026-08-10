import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/notifications/push_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/entities/notification_preference.dart';
import '../../../profile/presentation/providers/user_profile_provider.dart'
    show notificationPreferencesProvider;
import '../../data/datasources/notifications_remote_datasource.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../domain/usecases/mark_notifications_read_usecase.dart';
import '../../domain/usecases/watch_notifications_usecase.dart';
import '../widgets/notification_text.dart';

// ── Infrastructure ──────────────────────────────────────────────────────────

final notificationsRemoteDataSourceProvider =
    Provider<NotificationsRemoteDataSource>(
      (_) => const NotificationsRemoteDataSourceImpl(),
    );

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepositoryImpl(
    ref.watch(notificationsRemoteDataSourceProvider),
  ),
);

final watchNotificationsUseCaseProvider = Provider<WatchNotificationsUseCase>(
  (ref) =>
      WatchNotificationsUseCase(ref.watch(notificationsRepositoryProvider)),
);

final markNotificationsReadUseCaseProvider =
    Provider<MarkNotificationsReadUseCase>(
      (ref) => MarkNotificationsReadUseCase(
        ref.watch(notificationsRepositoryProvider),
      ),
    );

// ── Live feed ────────────────────────────────────────────────────────────────

/// The signed-in user's most recent notifications, newest first. Deliberately
/// NOT `.autoDispose` — kept alive for the whole authenticated session (like
/// `chatMessageWatcherProvider`) so it can back both the unread badge (read
/// from anywhere) and the foreground local-notification watcher
/// (`socialNotificationWatcherProvider`) without either one owning its
/// lifecycle. Empty (not an error) when signed out.
final notificationFeedProvider = StreamProvider<List<AppNotification>>((ref) {
  final auth = ref.watch(authNotifierProvider);
  if (auth is! AuthAuthenticated) {
    return Stream.value(const []);
  }
  return ref
      .watch(watchNotificationsUseCaseProvider)
      .call(auth.user.id)
      .map(
        (either) => either.fold((f) => throw Exception(f.message), (n) => n),
      );
});

/// Unread count for the bell badge — derived from the same capped feed
/// above, not a separate query.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationFeedProvider).value ?? const [];
  return notifications.where((n) => !n.isRead).length;
});

/// Set by `NotificationsPage` while it's the visible screen, so the
/// foreground watcher below doesn't pop a system notification for an event
/// the user is already looking at live in the list — same purpose as chat's
/// `activeChatIdProvider`.
final notificationsPageActiveProvider = StateProvider<bool>((_) => false);

// ---------------------------------------------------------------------------
// In-app activity notifications.
//
// Same split as chatMessageWatcherProvider (see that provider's doc): once
// real OS push is live for a platform (Android always; iOS once
// kIosPushReady flips on), it owns non-foreground delivery via
// send-social-push + push_message_handler.dart, and this watcher only fires
// while the app is actually resumed to avoid double delivery. Until then
// (iOS today), this best-effort in-process watcher is the only delivery
// mechanism there.
// ---------------------------------------------------------------------------

/// Watches [notificationFeedProvider] for the lifetime it's kept alive
/// (mounted once in `KumoShell`, alive for the whole authenticated session)
/// and fires a local notification when a new event lands.
final socialNotificationWatcherProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<AppNotification>>>(notificationFeedProvider, (
    prev,
    next,
  ) {
    // Only a data→data transition with a changed top id is a genuinely new
    // notification; the initial loading→data transition is just existing
    // history downloading, and a mark-all-read update re-emits the same top
    // id with a new readAt, not a new row.
    if (prev is! AsyncData<List<AppNotification>> ||
        next is! AsyncData<List<AppNotification>>) {
      return;
    }
    if (next.value.isEmpty) {
      return;
    }
    final latest = next.value.first;
    final prevLatestId = prev.value.isNotEmpty ? prev.value.first.id : null;
    if (latest.id == prevLatestId) {
      return;
    }
    _maybeNotify(ref, latest);
  });
});

void _maybeNotify(Ref ref, AppNotification notification) {
  if (ref.read(notificationsPageActiveProvider)) {
    return;
  }

  final isAndroid = defaultTargetPlatform == TargetPlatform.android;
  final isIosPushLive =
      defaultTargetPlatform == TargetPlatform.iOS && kIosPushReady;
  if ((isAndroid || isIosPushLive) &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    return;
  }

  final prefs = ref.read(notificationPreferencesProvider).value ?? const [];
  NotificationPreference? socialPref;
  for (final p in prefs) {
    if (p.channel == NotifChannel.push &&
        p.category == NotifCategory.socialActivity) {
      socialPref = p;
      break;
    }
  }
  // Default to enabled if prefs haven't loaded yet or no row exists — matches
  // the DB's own default (seed_notification_preferences seeds this true).
  if (socialPref?.enabled == false) {
    return;
  }

  final (title, body) = notificationText(notification);
  ref
      .read(notificationServiceProvider)
      .value
      ?.showSocialActivityNotification(
        actorId: notification.actorId,
        title: title,
        body: body,
      );
}
