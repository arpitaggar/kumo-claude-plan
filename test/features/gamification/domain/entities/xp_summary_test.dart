import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/gamification/domain/entities/xp_event.dart';
import 'package:kumo_claude/features/gamification/domain/entities/xp_summary.dart';

XpEvent _event(String sourceType, int amount) => XpEvent(
  id: 'evt-$sourceType-$amount',
  userId: 'user-1',
  amount: amount,
  reason: sourceType,
  sourceType: sourceType,
  sourceId: 'src-1',
  createdAt: DateTime.utc(2026),
);

void main() {
  group('XpSummary.fromEvents', () {
    test('returns all zeros for an empty list', () {
      final summary = XpSummary.fromEvents(const []);

      expect(summary, const XpSummary.zero());
    });

    test('sums amounts into totalXp and counts each source type', () {
      final summary = XpSummary.fromEvents([
        _event('trip_created', 10),
        _event('trip_created', 10),
        _event('trip_completed', 30),
        _event('post_published', 15),
        _event('post_liked', 2),
        _event('post_liked', 2),
        _event('post_liked', 2),
        _event('follower_gained', 5),
        _event('comment_posted', 3),
      ]);

      expect(summary.totalXp, 10 + 10 + 30 + 15 + 2 + 2 + 2 + 5 + 3);
      expect(summary.tripsCreated, 2);
      expect(summary.tripsCompleted, 1);
      expect(summary.postsPublished, 1);
      expect(summary.likesReceived, 3);
      expect(summary.followersGained, 1);
      expect(summary.commentsPosted, 1);
    });
  });

  group('XpSummary.valueFor', () {
    test('returns the matching field for every metric', () {
      const summary = XpSummary(
        totalXp: 123,
        tripsCreated: 1,
        tripsCompleted: 2,
        postsPublished: 3,
        likesReceived: 4,
        followersGained: 5,
        commentsPosted: 6,
      );

      expect(summary.valueFor(XpMetric.totalXp), 123);
      expect(summary.valueFor(XpMetric.tripsCreated), 1);
      expect(summary.valueFor(XpMetric.tripsCompleted), 2);
      expect(summary.valueFor(XpMetric.postsPublished), 3);
      expect(summary.valueFor(XpMetric.likesReceived), 4);
      expect(summary.valueFor(XpMetric.followersGained), 5);
      expect(summary.valueFor(XpMetric.commentsPosted), 6);
    });
  });

  group('level arithmetic', () {
    test('starts at level 1 with 0 XP', () {
      const summary = XpSummary.zero();

      expect(summary.level, 1);
      expect(summary.xpIntoLevel, 0);
      expect(summary.xpToNextLevel, 100);
    });

    test('stays level 1 right up to 99 XP', () {
      const summary = XpSummary(
        totalXp: 99,
        tripsCreated: 0,
        tripsCompleted: 0,
        postsPublished: 0,
        likesReceived: 0,
        followersGained: 0,
        commentsPosted: 0,
      );

      expect(summary.level, 1);
      expect(summary.xpIntoLevel, 99);
      expect(summary.xpToNextLevel, 1);
    });

    test('reaches level 2 at exactly 100 XP', () {
      const summary = XpSummary(
        totalXp: 100,
        tripsCreated: 0,
        tripsCompleted: 0,
        postsPublished: 0,
        likesReceived: 0,
        followersGained: 0,
        commentsPosted: 0,
      );

      expect(summary.level, 2);
      expect(summary.xpIntoLevel, 0);
      expect(summary.xpToNextLevel, 100);
    });

    test('handles a large total (e.g. level 5 at 423 XP)', () {
      const summary = XpSummary(
        totalXp: 423,
        tripsCreated: 0,
        tripsCompleted: 0,
        postsPublished: 0,
        likesReceived: 0,
        followersGained: 0,
        commentsPosted: 0,
      );

      expect(summary.level, 5);
      expect(summary.xpIntoLevel, 23);
      expect(summary.xpToNextLevel, 77);
    });
  });
}
