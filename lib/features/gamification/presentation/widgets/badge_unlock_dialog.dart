import 'package:flutter/material.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../domain/entities/gamification_badge.dart';
import '../providers/badge_unlock_notifier.dart' show BadgeUnlockNotifier;

/// Celebratory dialog shown the moment [BadgeUnlockNotifier.checkForNewBadges]
/// reports one or more newly-earned badges. All of them are listed in one
/// dialog rather than queued one-at-a-time — simpler, and the only case
/// where more than one unlocks at once is a returning user whose activity
/// already crossed several thresholds before this feature shipped.
Future<void> showBadgeUnlockDialog(
  BuildContext context,
  List<GamificationBadge> badges,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(
      badges.length == 1 ? 'New Badge Unlocked!' : 'New Badges Unlocked!',
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final badge in badges)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(badge.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        badge.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Nice!'),
      ),
    ],
  ),
);
