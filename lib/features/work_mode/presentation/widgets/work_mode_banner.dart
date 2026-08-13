import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/brand.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../providers/work_mode_provider.dart';

/// Always-reachable top strip showing which mode the user is in (Personal
/// vs. Work, tagged with the org name) with a toggle to switch. Invisible to
/// users who don't belong to any organization at all.
class WorkModeBanner extends ConsumerWidget {
  const WorkModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(isWorkModeAvailableProvider);
    if (!available) {
      return const SizedBox.shrink();
    }

    final active = ref.watch(isWorkModeActiveProvider);
    final org = ref.watch(currentWorkOrgProvider);
    final onInverse = context.colorScheme.onInverseSurface;

    return ColoredBox(
      color: context.colorScheme.inverseSurface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                active ? Icons.work_outline : Icons.person_outline,
                size: 16,
                color: onInverse,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  active && org != null
                      ? '${Brand.appName} — for ${org.name}'
                      : 'Personal',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: onInverse,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch.adaptive(
                value: active,
                onChanged: (value) => ref
                    .read(workModeProvider.notifier)
                    .setWorkMode(value: value),
                activeTrackColor: context.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
