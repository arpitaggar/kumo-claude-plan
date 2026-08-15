import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/brand.dart';
import '../../config/theme_provider.dart';
import '../../core/crash_reporting/crash_reporting_providers.dart';
import '../../core/crash_reporting/local_file_crash_reporter.dart';
import '../../core/maps/kumo_map_provider.dart';
import '../../core/premium/premium_feature.dart';
import '../../core/premium/premium_providers.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/gamification/presentation/widgets/gamification_card.dart';
import '../../features/itinerary/presentation/providers/itinerary_provider.dart';
import '../../features/work_mode/presentation/providers/work_mode_provider.dart';
import '../../shared/extensions/context_extensions.dart';
import '../../shared/widgets/kumo_avatar.dart';

// Per-provider display metadata used in the map provider picker.
const _kMapProviderMeta = {
  KumoMapProvider.openStreetMap: (
    label: 'OpenStreetMap',
    subtitle: 'Free, no account needed',
    icon: Icons.map_outlined,
  ),
  KumoMapProvider.googleMaps: (
    label: 'Google Maps',
    subtitle: 'Premium',
    icon: Icons.map,
  ),
};

// Per-theme display metadata used in the picker and the current-theme label.
const _kThemeMeta = {
  KumoTheme.cherryBlossom: (
    label: 'Cherry Blossom',
    accent: Color(0xFFD4667A),
    bg: Color(0xFFF5F2EB),
  ),
  KumoTheme.goldenHour: (
    label: 'Golden Hour',
    accent: Color(0xFFC97A20),
    bg: Color(0xFFFAF5E4),
  ),
  KumoTheme.deepVoyage: (
    label: 'Deep Voyage',
    accent: Color(0xFFC88A2A),
    bg: Color(0xFF0E1B33),
  ),
  KumoTheme.synthwaveTokyo: (
    label: 'Synthwave Tokyo',
    accent: Color(0xFFFF9152),
    bg: Color(0xFF2A0F52),
  ),
  KumoTheme.whiteAndCharcoal: (
    label: 'White & Charcoal',
    accent: Color(0xFF2B2B2E),
    bg: Color(0xFFFAFAFA),
  ),
  KumoTheme.warmOatLightBlue: (
    label: 'Warm Oat & Light Blue',
    accent: Color(0xFF3D84C6),
    bg: Color(0xFFF6EFE2),
  ),
  KumoTheme.sunsetCoral: (
    label: 'Sunset Coral',
    accent: Color(0xFFC1442C),
    bg: Color(0xFFFBF1EB),
  ),
  KumoTheme.dawnFlight: (
    label: 'Dawn Flight',
    accent: Color(0xFFF2A65A),
    bg: Color(0xFF1B2A4A),
  ),
  KumoTheme.verdigrisBronze: (
    label: 'Verdigris Bronze',
    accent: Color(0xFF3F7A6E),
    bg: Color(0xFFF0F2EC),
  ),
  KumoTheme.cloudSilver: (
    label: 'Cloud Silver',
    accent: Color(0xFF1E9A85),
    bg: Color(0xFFF3F6FA),
  ),
};

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final currentTheme = ref.watch(themeProvider);
    final currentMapProvider = ref.watch(mapProviderConfigProvider);
    final workModeActive = ref.watch(isWorkModeActiveProvider);
    final workModeAvailable = ref.watch(isWorkModeAvailableProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: context.colorScheme.onSurface,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                KumoAvatar(
                  sourceUrl: user?.avatarUrl,
                  radius: 44,
                  backgroundColor: context.colorScheme.primaryContainer,
                  fallback: Text(
                    user?.displayName?.isNotEmpty == true
                        ? user!.displayName![0].toUpperCase()
                        : user?.email[0].toUpperCase() ?? '?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: context.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName ?? 'Traveler',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _StatsCard(),
          const SizedBox(height: 12),
          const GamificationCard(),
          const SizedBox(height: 24),
          const _SectionHeader('Appearance'),
          const SizedBox(height: 8),
          if (workModeActive)
            _tile(
              context,
              icon: Icons.palette_outlined,
              label: 'Theme: Onyx & Gold (locked by Work Mode)',
              onTap: () => context.showSnackBar(
                'Switch to Personal mode to change your theme.',
              ),
            )
          else
            _tile(
              context,
              icon: Icons.palette_outlined,
              label: 'Theme: ${_kThemeMeta[currentTheme]!.label}',
              trailing: _ThemeSwatch(theme: currentTheme),
              onTap: () => _showThemePicker(context, ref),
            ),
          const SizedBox(height: 8),
          _tile(
            context,
            icon: _kMapProviderMeta[currentMapProvider]!.icon,
            label: 'Map: ${_kMapProviderMeta[currentMapProvider]!.label}',
            onTap: () => _showMapProviderPicker(context, ref),
          ),
          const SizedBox(height: 24),
          const _SectionHeader('Account'),
          const SizedBox(height: 8),
          _tile(
            context,
            icon: Icons.edit_outlined,
            label: 'Edit Profile',
            onTap: () => context.push('/profile/edit'),
          ),
          const SizedBox(height: 8),
          _tile(
            context,
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () => context.push('/profile/notifications'),
          ),
          const SizedBox(height: 8),
          _tile(
            context,
            icon: Icons.lock_outline,
            label: 'Privacy Settings',
            onTap: () => context.push('/settings/privacy'),
          ),
          if (workModeAvailable) ...[
            const SizedBox(height: 8),
            _tile(
              context,
              icon: Icons.work_outline,
              label: 'My Organizations',
              onTap: () => context.push('/organizations'),
            ),
          ],
          const SizedBox(height: 8),
          _tile(
            context,
            icon: Icons.bug_report_outlined,
            label: 'Share Debug Log',
            onTap: () => _shareDebugLog(context, ref),
          ),
          const SizedBox(height: 8),
          _tile(
            context,
            icon: Icons.logout,
            label: 'Sign Out',
            color: context.colorScheme.primary,
            onTap: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }

  /// Lets a user hand over `crashReporterProvider`'s local log directly —
  /// today's only way to get an error record off a real device, since this
  /// app has no remote crash-reporting backend (see `crash_reporter.dart`'s
  /// doc comment). `ExportableCrashLog` is implemented only by reporters
  /// that keep a local, shareable file — a future Sentry/Crashlytics
  /// backend wouldn't, so this tile would need to become a "view online"
  /// link instead at that point, not a share sheet.
  Future<void> _shareDebugLog(BuildContext context, WidgetRef ref) async {
    // Pattern-matched, not a plain `is` check + cast — CrashReporter and
    // ExportableCrashLog are unrelated sibling interfaces (a single impl
    // happens to implement both), so a bare `is` check can't promote the
    // provider's declared CrashReporter type to ExportableCrashLog; this
    // binds a correctly-typed variable directly instead.
    final reporter = ref.read(crashReporterProvider);
    if (reporter is! ExportableCrashLog) {
      context.showSnackBar(
        'Debug log sharing is not available.',
        isError: true,
      );
      return;
    }

    final file = await (reporter as ExportableCrashLog).exportFile();
    if (!context.mounted) {
      return;
    }
    if (file == null) {
      context.showSnackBar('No debug log recorded yet.');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: '${Brand.appName} debug log',
        text: 'Debug log from ${Brand.appName}.',
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ThemePickerSheet(currentRef: ref),
    );
  }

  void _showMapProviderPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MapProviderPickerSheet(currentRef: ref),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    Widget? trailing,
  }) {
    final effectiveColor = color ?? context.colorScheme.onSurface;
    return Material(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: effectiveColor, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: effectiveColor,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ] else
                Icon(
                  Icons.chevron_right,
                  color: context.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: context.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

// ── Theme swatch (small preview used in the tile trailing area) ─────────────

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme});

  final KumoTheme theme;

  @override
  Widget build(BuildContext context) {
    final meta = _kThemeMeta[theme]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: meta.bg,
            shape: BoxShape.circle,
            border: Border.all(color: context.colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: meta.accent,
            shape: BoxShape.circle,
            border: Border.all(color: context.colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.chevron_right,
          color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}

// ── Theme picker bottom sheet ──────────────────────────────────────────────

class _ThemePickerSheet extends ConsumerWidget {
  const _ThemePickerSheet({required this.currentRef});

  // We receive the parent ref so we can dispatch setTheme without a new
  // ProviderScope being required inside the modal route.
  final WidgetRef currentRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeProvider);
    // The list of themes can grow past the screen height (6+ options), so
    // the sheet is capped and the option list scrolls internally while the
    // header stays fixed — the header itself was overflowing the sheet
    // before this fix once a 4th+ theme was added.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'App Theme',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how ${Brand.appName} looks. Your choice syncs with the app icon.',
            style: TextStyle(
              fontSize: 13,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                children: KumoTheme.values
                    .where((t) => t != KumoTheme.onyxGold)
                    .map(
                      (t) => _ThemeOption(
                        theme: t,
                        isSelected: t == selected,
                        onTap: () {
                          currentRef.read(themeProvider.notifier).setTheme(t);
                          Navigator.of(context).pop();
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  final KumoTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = _kThemeMeta[theme]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected
            ? context.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : context.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Color preview
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      children: [
                        Container(color: meta.bg),
                        Positioned(
                          right: -8,
                          bottom: -8,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: meta.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    meta.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: context.colorScheme.primary,
                  )
                else
                  Icon(
                    Icons.circle_outlined,
                    color: context.colorScheme.outlineVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Map provider picker bottom sheet ───────────────────────────────────────────

class _MapProviderPickerSheet extends ConsumerWidget {
  const _MapProviderPickerSheet({required this.currentRef});

  final WidgetRef currentRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(mapProviderConfigProvider);
    final canUseGoogleMaps = ref.watch(
      canUseFeatureProvider(PremiumFeatureKeys.googleMaps),
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Route Map',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose which map renders your trip route.',
            style: TextStyle(
              fontSize: 13,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          for (final provider in KumoMapProvider.values)
            _MapProviderOption(
              provider: provider,
              isSelected: provider == selected,
              isLocked:
                  provider == KumoMapProvider.googleMaps && !canUseGoogleMaps,
              onTap: () {
                if (provider == KumoMapProvider.googleMaps &&
                    !canUseGoogleMaps) {
                  context.showSnackBar(
                    'Google Maps is a premium feature. Upgrade to unlock it.',
                  );
                  return;
                }
                currentRef
                    .read(mapProviderConfigProvider.notifier)
                    .setProvider(provider);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

class _MapProviderOption extends StatelessWidget {
  const _MapProviderOption({
    required this.provider,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  });

  final KumoMapProvider provider;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = _kMapProviderMeta[provider]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected
            ? context.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : context.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(meta.icon, color: context.colorScheme.onSurface),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        meta.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLocked)
                  Icon(
                    Icons.lock_outline,
                    color: context.colorScheme.onSurfaceVariant,
                  )
                else if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: context.colorScheme.primary,
                  )
                else
                  Icon(
                    Icons.circle_outlined,
                    color: context.colorScheme.outlineVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stats card ─────────────────────────────────────────────────────────────────

class _StatsCard extends ConsumerWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(itineraryListProvider);
    if (listState is! ItineraryListLoaded) {
      return const SizedBox.shrink();
    }

    final trips = listState.itineraries;
    final now = DateTime.now();
    final upcoming = trips.where((t) => t.startDate.isAfter(now)).length;
    final daysTraveled = trips
        .where((t) => t.endDate.isBefore(now))
        .fold(
          0,
          (sum, t) => sum + t.endDate.difference(t.startDate).inDays + 1,
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatPill(value: '${trips.length}', label: 'Trips'),
          Container(
            width: 1,
            height: 32,
            color: context.colorScheme.outlineVariant,
          ),
          _StatPill(value: '$upcoming', label: 'Upcoming'),
          Container(
            width: 1,
            height: 32,
            color: context.colorScheme.outlineVariant,
          ),
          _StatPill(value: '$daysTraveled', label: 'Days traveled'),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: context.colorScheme.primary,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
