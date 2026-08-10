import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notifications_provider.dart';
import '../widgets/notification_text.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  // Cached rather than read fresh in dispose() — `ref` isn't safe to use
  // once this State is disposed. Same pattern as ChatPage's
  // `_activeChatIdController`.
  late final StateController<bool> _activeController;

  // Guards against calling markAllRead more than once. Not set from
  // initState's postFrameCallback alone: on a very first launch,
  // authNotifierProvider's own getCurrentUser() may still be resolving by
  // the time that first frame's callback runs, so build() below also checks
  // on every rebuild until the guard trips.
  bool _markedRead = false;

  @override
  void initState() {
    super.initState();
    _activeController = ref.read(notificationsPageActiveProvider.notifier);
    // Riverpod forbids writing to a provider mid-build (initState counts),
    // so this is deferred to the post-frame callback rather than done here
    // directly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activeController.state = true;
    });
  }

  void _maybeMarkRead(AuthState auth) {
    if (_markedRead || auth is! AuthAuthenticated) {
      return;
    }
    _markedRead = true;
    ref.read(markNotificationsReadUseCaseProvider).call(auth.user.id);
  }

  @override
  void dispose() {
    // `mounted` here is the StateController's own (it can already be torn
    // down by the time this microtask runs — e.g. the whole ProviderScope
    // going away right behind this page), not this State's.
    Future.microtask(() {
      if (_activeController.mounted) {
        _activeController.state = false;
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _maybeMarkRead(ref.watch(authNotifierProvider));
    final feedAsync = ref.watch(notificationFeedProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Activity',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: context.colorScheme.onSurface,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: feedAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colorScheme.primary),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load activity.',
            style: TextStyle(color: context.colorScheme.onSurfaceVariant),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 56,
                    color: context.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No activity yet',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Likes, follows, and new posts from people\nyou follow will show up here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 76,
              color: context.colorScheme.outlineVariant,
            ),
            itemBuilder: (context, i) =>
                _NotificationTile(notification: notifications[i]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  IconData get _icon => switch (notification.type) {
    NotificationType.like => Icons.favorite,
    NotificationType.follow => Icons.person_add_alt_1,
    NotificationType.newPost => Icons.card_travel,
    NotificationType.comment => Icons.mode_comment,
  };

  @override
  Widget build(BuildContext context) {
    final (title, body) = notificationText(notification);

    return InkWell(
      onTap: () => context.push('/u/${notification.actorId}'),
      child: Container(
        color: notification.isRead
            ? null
            : context.colorScheme.primaryContainer.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: context.colorScheme.primaryContainer,
              backgroundImage: notification.actorAvatarUrl != null
                  ? NetworkImage(notification.actorAvatarUrl!)
                  : null,
              child: notification.actorAvatarUrl == null
                  ? Icon(
                      _icon,
                      size: 18,
                      color: context.colorScheme.onPrimaryContainer,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    _formatTime(notification.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);
    if (diff.inDays == 0) {
      return DateFormat('h:mm a').format(local);
    }
    if (diff.inDays < 7) {
      return DateFormat('EEE').format(local);
    }
    return DateFormat('MMM d').format(local);
  }
}
