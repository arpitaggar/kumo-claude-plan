import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../domain/entities/gamification_badge.dart';
import '../../domain/entities/xp_summary.dart';
import '../providers/badge_unlock_notifier.dart';
import '../providers/gamification_provider.dart';
import 'badge_unlock_dialog.dart';

/// Profile-page summary card: level + XP progress + badge count, tappable
/// through to `/achievements`. Inserted directly after `_StatsCard`.
class GamificationCard extends ConsumerWidget {
  const GamificationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.listen, not a manual postFrameCallback — this is Riverpod's own
    // supported way to run a side effect (checking/celebrating a newly
    // earned badge) in response to a provider transitioning to a value,
    // safely outside the build phase.
    ref.listen<AsyncValue<XpSummary>>(xpSummaryProvider, (previous, next) {
      final summary = next.value;
      if (summary == null) {
        return;
      }
      unawaited(_checkAndCelebrate(context, ref, summary));
    });

    final summary = ref.watch(xpSummaryProvider).value;
    if (summary == null) {
      return const SizedBox.shrink();
    }

    final earnedCount = GamificationBadge.all
        .where((b) => b.isEarnedBy(summary))
        .length;

    return Material(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/achievements'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Level ${summary.level}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$earnedCount/${GamificationBadge.all.length} badges',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: context.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: summary.xpIntoLevel / 100,
                  minHeight: 6,
                  backgroundColor: context.colorScheme.outlineVariant,
                  valueColor: AlwaysStoppedAnimation(
                    context.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${summary.xpIntoLevel}/100 XP to next level',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkAndCelebrate(
    BuildContext context,
    WidgetRef ref,
    XpSummary summary,
  ) async {
    final newBadges = await ref
        .read(badgeUnlockNotifierProvider.notifier)
        .checkForNewBadges(summary);
    if (newBadges.isNotEmpty && context.mounted) {
      await showBadgeUnlockDialog(context, newBadges);
    }
  }
}
