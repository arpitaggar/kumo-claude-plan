import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/gamification/domain/entities/gamification_badge.dart';
import 'package:kumo_claude/features/gamification/domain/entities/xp_summary.dart';

XpSummary _summaryWith(XpMetric metric, int value) {
  const zero = XpSummary.zero();
  return switch (metric) {
    XpMetric.totalXp => XpSummary(
      totalXp: value,
      tripsCreated: zero.tripsCreated,
      tripsCompleted: zero.tripsCompleted,
      postsPublished: zero.postsPublished,
      likesReceived: zero.likesReceived,
      followersGained: zero.followersGained,
      commentsPosted: zero.commentsPosted,
    ),
    XpMetric.tripsCreated => XpSummary(
      totalXp: 0,
      tripsCreated: value,
      tripsCompleted: 0,
      postsPublished: 0,
      likesReceived: 0,
      followersGained: 0,
      commentsPosted: 0,
    ),
    XpMetric.tripsCompleted => XpSummary(
      totalXp: 0,
      tripsCreated: 0,
      tripsCompleted: value,
      postsPublished: 0,
      likesReceived: 0,
      followersGained: 0,
      commentsPosted: 0,
    ),
    XpMetric.postsPublished => XpSummary(
      totalXp: 0,
      tripsCreated: 0,
      tripsCompleted: 0,
      postsPublished: value,
      likesReceived: 0,
      followersGained: 0,
      commentsPosted: 0,
    ),
    XpMetric.likesReceived => XpSummary(
      totalXp: 0,
      tripsCreated: 0,
      tripsCompleted: 0,
      postsPublished: 0,
      likesReceived: value,
      followersGained: 0,
      commentsPosted: 0,
    ),
    XpMetric.followersGained => XpSummary(
      totalXp: 0,
      tripsCreated: 0,
      tripsCompleted: 0,
      postsPublished: 0,
      likesReceived: 0,
      followersGained: value,
      commentsPosted: 0,
    ),
    XpMetric.commentsPosted => XpSummary(
      totalXp: 0,
      tripsCreated: 0,
      tripsCompleted: 0,
      postsPublished: 0,
      likesReceived: 0,
      followersGained: 0,
      commentsPosted: value,
    ),
  };
}

void main() {
  group('GamificationBadge.all', () {
    test('has 8 badges with unique keys', () {
      expect(GamificationBadge.all, hasLength(8));
      final keys = GamificationBadge.all.map((b) => b.key).toSet();
      expect(keys, hasLength(8));
    });
  });

  group('GamificationBadge.isEarnedBy', () {
    for (final badge in GamificationBadge.all) {
      test('${badge.key}: locked one below threshold, earned at and above '
          'threshold', () {
        final justBelow = _summaryWith(badge.metric, badge.threshold - 1);
        final atThreshold = _summaryWith(badge.metric, badge.threshold);
        final aboveThreshold = _summaryWith(badge.metric, badge.threshold + 1);

        expect(badge.isEarnedBy(justBelow), isFalse);
        expect(badge.isEarnedBy(atThreshold), isTrue);
        expect(badge.isEarnedBy(aboveThreshold), isTrue);
      });
    }
  });
}
