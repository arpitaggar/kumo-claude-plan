import 'package:equatable/equatable.dart';

import 'xp_summary.dart';

/// A single unlockable achievement, defined purely as a threshold over one
/// [XpMetric] — no separate `badges`/`user_badges` table exists server-side;
/// "earned or not" is derived fresh from an [XpSummary] every time. Named
/// `GamificationBadge`, not `Badge`, to avoid colliding with
/// `flutter/material.dart`'s own `Badge` widget in files that need both.
class GamificationBadge extends Equatable {
  const GamificationBadge({
    required this.key,
    required this.label,
    required this.description,
    required this.emoji,
    required this.metric,
    required this.threshold,
  });

  final String key;
  final String label;
  final String description;
  final String emoji;
  final XpMetric metric;
  final int threshold;

  bool isEarnedBy(XpSummary summary) => summary.valueFor(metric) >= threshold;

  static const firstSteps = GamificationBadge(
    key: 'first_steps',
    label: 'First Steps',
    description: 'Plan your first trip',
    emoji: '🧳',
    metric: XpMetric.tripsCreated,
    threshold: 1,
  );

  static const wanderer = GamificationBadge(
    key: 'wanderer',
    label: 'Wanderer',
    description: 'Complete your first trip',
    emoji: '🗺️',
    metric: XpMetric.tripsCompleted,
    threshold: 1,
  );

  static const globetrotter = GamificationBadge(
    key: 'globetrotter',
    label: 'Globetrotter',
    description: 'Complete 5 trips',
    emoji: '🌍',
    metric: XpMetric.tripsCompleted,
    threshold: 5,
  );

  static const storyteller = GamificationBadge(
    key: 'storyteller',
    label: 'Storyteller',
    description: 'Publish your first trip to Discover',
    emoji: '📖',
    metric: XpMetric.postsPublished,
    threshold: 1,
  );

  static const popular = GamificationBadge(
    key: 'popular',
    label: 'Popular',
    description: 'Get 10 likes on your published trips',
    emoji: '❤️',
    metric: XpMetric.likesReceived,
    threshold: 10,
  );

  static const influencer = GamificationBadge(
    key: 'influencer',
    label: 'Influencer',
    description: 'Gain 10 followers',
    emoji: '⭐',
    metric: XpMetric.followersGained,
    threshold: 10,
  );

  static const conversationalist = GamificationBadge(
    key: 'conversationalist',
    label: 'Conversationalist',
    description: 'Leave 10 comments',
    emoji: '💬',
    metric: XpMetric.commentsPosted,
    threshold: 10,
  );

  static const centuryClub = GamificationBadge(
    key: 'century_club',
    label: 'Century Club',
    description: 'Earn 100 XP',
    emoji: '🏆',
    metric: XpMetric.totalXp,
    threshold: 100,
  );

  static const all = [
    firstSteps,
    wanderer,
    globetrotter,
    storyteller,
    popular,
    influencer,
    conversationalist,
    centuryClub,
  ];

  @override
  List<Object?> get props => [
    key,
    label,
    description,
    emoji,
    metric,
    threshold,
  ];
}
