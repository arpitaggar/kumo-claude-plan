import 'package:equatable/equatable.dart';

import 'gamification_badge.dart' show GamificationBadge;
import 'xp_event.dart';

/// A countable dimension of a user's activity, used to key a
/// [GamificationBadge]'s unlock threshold against the right number.
enum XpMetric {
  totalXp,
  tripsCreated,
  tripsCompleted,
  postsPublished,
  likesReceived,
  followersGained,
  commentsPosted,
}

/// A user's XP totals, derived client-side by folding their own
/// [XpEvent] list — the events themselves are the source of truth (fetched
/// once per `docs/supabase_migrations/stage40_gamification.sql`'s row
/// volume expectations), not a separately-stored rollup.
class XpSummary extends Equatable {
  const XpSummary({
    required this.totalXp,
    required this.tripsCreated,
    required this.tripsCompleted,
    required this.postsPublished,
    required this.likesReceived,
    required this.followersGained,
    required this.commentsPosted,
  });

  const XpSummary.zero()
    : totalXp = 0,
      tripsCreated = 0,
      tripsCompleted = 0,
      postsPublished = 0,
      likesReceived = 0,
      followersGained = 0,
      commentsPosted = 0;

  factory XpSummary.fromEvents(List<XpEvent> events) {
    var totalXp = 0;
    var tripsCreated = 0;
    var tripsCompleted = 0;
    var postsPublished = 0;
    var likesReceived = 0;
    var followersGained = 0;
    var commentsPosted = 0;

    for (final event in events) {
      totalXp += event.amount;
      switch (event.sourceType) {
        case 'trip_created':
          tripsCreated++;
        case 'trip_completed':
          tripsCompleted++;
        case 'post_published':
          postsPublished++;
        case 'post_liked':
          likesReceived++;
        case 'follower_gained':
          followersGained++;
        case 'comment_posted':
          commentsPosted++;
      }
    }

    return XpSummary(
      totalXp: totalXp,
      tripsCreated: tripsCreated,
      tripsCompleted: tripsCompleted,
      postsPublished: postsPublished,
      likesReceived: likesReceived,
      followersGained: followersGained,
      commentsPosted: commentsPosted,
    );
  }

  final int totalXp;
  final int tripsCreated;
  final int tripsCompleted;
  final int postsPublished;
  final int likesReceived;
  final int followersGained;
  final int commentsPosted;

  int valueFor(XpMetric metric) => switch (metric) {
    XpMetric.totalXp => totalXp,
    XpMetric.tripsCreated => tripsCreated,
    XpMetric.tripsCompleted => tripsCompleted,
    XpMetric.postsPublished => postsPublished,
    XpMetric.likesReceived => likesReceived,
    XpMetric.followersGained => followersGained,
    XpMetric.commentsPosted => commentsPosted,
  };

  /// 100 XP per level, starting at level 1.
  int get level => 1 + totalXp ~/ 100;

  /// XP earned within the current level (0-99).
  int get xpIntoLevel => totalXp % 100;

  /// XP still needed to reach the next level.
  int get xpToNextLevel => 100 - xpIntoLevel;

  @override
  List<Object?> get props => [
    totalXp,
    tripsCreated,
    tripsCompleted,
    postsPublished,
    likesReceived,
    followersGained,
    commentsPosted,
  ];
}
