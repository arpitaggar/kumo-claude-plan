import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/gamification_badge.dart';
import '../../domain/entities/xp_event.dart';
import '../../domain/entities/xp_summary.dart';
import '../providers/gamification_provider.dart';

class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(xpSummaryProvider);
    final eventsAsync = ref.watch(xpEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: summaryAsync.when(
        loading: () => const LoadingWidget(message: 'Loading achievements…'),
        error: (_, _) => AppErrorWidget(
          message: "Couldn't load your achievements.",
          onRetry: () => ref.invalidate(xpEventsProvider),
        ),
        data: (summary) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _LevelHeader(summary: summary),
            const SizedBox(height: 24),
            Text('Badges', style: context.textTheme.labelLarge),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
              children: [
                for (final badge in GamificationBadge.all)
                  _BadgeTile(badge: badge, earned: badge.isEarnedBy(summary)),
              ],
            ),
            const SizedBox(height: 24),
            Text('Recent activity', style: context.textTheme.labelLarge),
            const SizedBox(height: 8),
            eventsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (events) => events.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Plan a trip, publish it, or engage with the '
                        'community to start earning XP.',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final event in events.take(10))
                          _ActivityRow(event: event),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.summary});

  final XpSummary summary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Level ${summary.level}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${summary.totalXp} XP total',
          style: TextStyle(
            fontSize: 13,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: summary.xpIntoLevel / 100,
            minHeight: 8,
            backgroundColor: context.colorScheme.outlineVariant,
            valueColor: AlwaysStoppedAnimation(context.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${summary.xpToNextLevel} XP to level ${summary.level + 1}',
          style: TextStyle(
            fontSize: 11,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.earned});

  final GamificationBadge badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = context.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: badge.description,
      child: Opacity(
        opacity: earned ? 1 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: earned
                    ? context.colorScheme.primaryContainer
                    : context.colorScheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Text(badge.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 6),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: earned
                    ? context.colorScheme.onSurface
                    : onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.event});

  final XpEvent event;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            event.reason,
            style: TextStyle(
              fontSize: 13,
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
        Text(
          '+${event.amount} XP',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatTime(event.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  // Same shape as comments_sheet.dart's _formatTime.
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
