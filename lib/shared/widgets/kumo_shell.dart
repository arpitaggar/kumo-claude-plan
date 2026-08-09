import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/notification_providers.dart';
import '../../features/chat/presentation/providers/chat_provider.dart';
import '../extensions/context_extensions.dart';
import 'offline_banner.dart';

class KumoShell extends ConsumerWidget {
  const KumoShell({required this.child, super.key});

  final Widget child;

  static const _destinations = [
    _NavDest('/home', Icons.home_outlined, Icons.home, 'Home'),
    _NavDest('/trips', Icons.luggage_outlined, Icons.luggage, 'Trips'),
    _NavDest('/inbox', Icons.chat_bubble_outline, Icons.chat_bubble, 'Inbox'),
    _NavDest('/discover', Icons.explore_outlined, Icons.explore, 'Discover'),
    _NavDest('/profile', Icons.person_outline, Icons.person, 'Profile'),
  ];

  static const _inboxIndex = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    var activeIndex = 0;
    for (var i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].path)) {
        activeIndex = i;
        break;
      }
    }

    final hasUnread = ref.watch(inboxHasUnreadProvider);

    // Keeps the new-message watcher and FCM token registration alive for the
    // whole authenticated session, and requests notification permission once
    // it's ready.
    ref
      ..watch(chatMessageWatcherProvider)
      ..watch(fcmTokenSyncProvider)
      ..listen(notificationServiceProvider, (_, next) {
        next.value?.requestPermissionOnce();
      });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.onSurface.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: activeIndex,
          onDestinationSelected: (i) => context.go(_destinations[i].path),
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: List.generate(_destinations.length, (i) {
            final d = _destinations[i];
            final icon = i == _inboxIndex && hasUnread
                ? _BadgedIcon(icon: d.icon)
                : Icon(d.icon);
            final selectedIcon = i == _inboxIndex && hasUnread
                ? _BadgedIcon(icon: d.activeIcon)
                : Icon(d.activeIcon);
            return NavigationDestination(
              icon: icon,
              selectedIcon: selectedIcon,
              label: d.label,
            );
          }),
        ),
      ),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Icon(icon),
      Positioned(
        top: -2,
        right: -4,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: context.colorScheme.error,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ],
  );
}

class _NavDest {
  const _NavDest(this.path, this.icon, this.activeIcon, this.label);
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
