import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/social/domain/entities/follow_stats.dart';
import 'package:kumo_claude/features/social/domain/repositories/follow_repository.dart';
import 'package:kumo_claude/features/social/domain/usecases/fetch_follow_stats_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  late MockFollowRepository mockRepo;

  setUp(() {
    mockRepo = MockFollowRepository();
  });

  test('delegates with userId/currentUserId', () async {
    const stats = FollowStats(
      followerCount: 3,
      followingCount: 5,
      isFollowedByMe: true,
    );
    when(
      () =>
          mockRepo.fetchFollowStats(userId: 'user-2', currentUserId: 'user-1'),
    ).thenAnswer((_) async => const Right(stats));

    final result = await FetchFollowStatsUseCase(
      mockRepo,
    ).call(userId: 'user-2', currentUserId: 'user-1');

    verify(
      () =>
          mockRepo.fetchFollowStats(userId: 'user-2', currentUserId: 'user-1'),
    ).called(1);
    result.fold(
      (_) => fail('expected Right'),
      (s) => expect(s.followerCount, 3),
    );
  });

  test('propagates failure from repository', () async {
    when(
      () => mockRepo.fetchFollowStats(
        userId: any(named: 'userId'),
        currentUserId: any(named: 'currentUserId'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await FetchFollowStatsUseCase(
      mockRepo,
    ).call(userId: 'user-2', currentUserId: 'user-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
