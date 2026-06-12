import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';

class KumoShell extends StatelessWidget {
  const KumoShell({required this.child, super.key});

  final Widget child;

  static const _destinations = [
    _NavDest('/home',     Icons.home_outlined,        Icons.home,        'Home'),
    _NavDest('/trips',    Icons.luggage_outlined,      Icons.luggage,     'Trips'),
    _NavDest('/inbox',    Icons.chat_bubble_outline,   Icons.chat_bubble, 'Inbox'),
    _NavDest('/discover', Icons.explore_outlined,      Icons.explore,     'Discover'),
    _NavDest('/profile',  Icons.person_outline,        Icons.person,      'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    var activeIndex = 0;
    for (var i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].path)) {
        activeIndex = i;
        break;
      }
    }

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
          destinations: _destinations
              .map((d) => NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.activeIcon),
                    label: d.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _NavDest {
  const _NavDest(this.path, this.icon, this.activeIcon, this.label);
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
