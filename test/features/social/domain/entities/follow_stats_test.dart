import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/social/domain/entities/follow_stats.dart';

void main() {
  const tStats = FollowStats(
    followerCount: 3,
    followingCount: 5,
    isFollowedByMe: false,
  );

  group('copyWith', () {
    test('overrides followerCount when provided', () {
      final result = tStats.copyWith(followerCount: 4);

      expect(result.followerCount, 4);
      expect(result.followingCount, 5);
      expect(result.isFollowedByMe, isFalse);
    });

    test('overrides isFollowedByMe when provided', () {
      final result = tStats.copyWith(isFollowedByMe: true);

      expect(result.isFollowedByMe, isTrue);
      expect(result.followerCount, 3);
    });

    test(
      'keeps followingCount unchanged — copyWith has no parameter for it',
      () {
        final result = tStats.copyWith(followerCount: 100);

        expect(result.followingCount, 5);
      },
    );

    test('returns an equal instance when called with no arguments', () {
      expect(tStats.copyWith(), tStats);
    });
  });

  group('equality', () {
    test('two instances with the same fields are equal', () {
      expect(
        tStats,
        const FollowStats(
          followerCount: 3,
          followingCount: 5,
          isFollowedByMe: false,
        ),
      );
    });

    test('instances differing in isFollowedByMe are not equal', () {
      expect(
        tStats,
        isNot(
          const FollowStats(
            followerCount: 3,
            followingCount: 5,
            isFollowedByMe: true,
          ),
        ),
      );
    });
  });
}
