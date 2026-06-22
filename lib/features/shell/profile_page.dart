import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      backgroundColor: AppTheme.warmOatmeal,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: AppTheme.darkEspresso,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.cherryBlossom,
                  backgroundImage: user?.avatarUrl != null
                      ? NetworkImage(user!.avatarUrl!)
                      : null,
                  child: user?.avatarUrl == null
                      ? Text(
                          user?.displayName?.isNotEmpty == true
                              ? user!.displayName![0].toUpperCase()
                              : user?.email[0].toUpperCase() ?? '?',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.softCoral,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName ?? 'Traveler',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkEspresso,
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.earthBrown,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          _tile(
            icon: Icons.edit_outlined,
            label: 'Edit Profile',
            onTap: () => context.push('/profile/edit'),
          ),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.lock_outline,
            label: 'Privacy Settings',
            onTap: () => context.push('/settings/privacy'),
          ),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.logout,
            label: 'Sign Out',
            color: AppTheme.softCoral,
            onTap: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppTheme.darkEspresso,
  }) => Material(
        color: AppTheme.cloudWhite,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right,
                    color: AppTheme.earthBrown.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      );
}
