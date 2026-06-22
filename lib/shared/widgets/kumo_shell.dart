import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../features/chat/presentation/providers/chat_provider.dart';

class KumoShell extends ConsumerWidget {
  const KumoShell({required this.child, super.key});

  final Widget child;

  static const _destinations = [
    _NavDest('/home',     Icons.home_outlined,        Icons.home,        'Home'),
    _NavDest('/trips',    Icons.luggage_outlined,      Icons.luggage,     'Trips'),
    _NavDest('/inbox',    Icons.chat_bubble_outline,   Icons.chat_bubble, 'Inbox'),
    _NavDest('/discover', Icons.explore_outlined,      Icons.explore,     'Discover'),
    _NavDest('/profile',  Icons.person_outline,        Icons.person,      'Profile'),
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

    return Scaffold(
      backgroundColor: AppTheme.warmOatmeal,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cloudWhite,
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkEspresso.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: activeIndex,
          onDestinationSelected: (i) => context.go(_destinations[i].path),
          backgroundColor: AppTheme.cloudWhite,
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
              decoration: const BoxDecoration(
                color: AppTheme.softCoral,
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
