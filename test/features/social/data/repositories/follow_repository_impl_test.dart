import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/social/data/datasources/social_remote_datasource.dart';
import 'package:kumo_claude/features/social/data/repositories/follow_repository_impl.dart';
import 'package:kumo_claude/features/social/domain/entities/follow_stats.dart';
import 'package:mocktail/mocktail.dart';

class MockSocialRemoteDataSource extends Mock
    implements SocialRemoteDataSource {}

void main() {
  late MockSocialRemoteDataSource dataSource;
  late FollowRepositoryImpl repository;

  setUp(() {
    dataSource = MockSocialRemoteDataSource();
    repository = FollowRepositoryImpl(dataSource);
  });

  group('toggleFollow', () {
    test('returns Right(null) on success', () async {
      when(
        () => dataSource.toggleFollow(
          followerId: any(named: 'followerId'),
          followeeId: any(named: 'followeeId'),
          follow: any(named: 'follow'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.toggleFollow(
        followerId: 'user-1',
        followeeId: 'user-2',
        follow: true,
      );

      expect(result, const Right<Failure, void>(null));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.toggleFollow(
          followerId: any(named: 'followerId'),
          followeeId: any(named: 'followeeId'),
          follow: any(named: 'follow'),
        ),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.toggleFollow(
        followerId: 'user-1',
        followeeId: 'user-2',
        follow: false,
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('fetchFollowStats', () {
    test('returns Right(stats) on success', () async {
      const stats = FollowStats(
        followerCount: 3,
        followingCount: 5,
        isFollowedByMe: true,
      );
      when(
        () => dataSource.fetchFollowStats(
          userId: any(named: 'userId'),
          currentUserId: any(named: 'currentUserId'),
        ),
      ).thenAnswer((_) async => stats);

      final result = await repository.fetchFollowStats(
        userId: 'user-1',
        currentUserId: 'user-2',
      );

      result.fold((_) => fail('expected Right'), (s) => expect(s, stats));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.fetchFollowStats(
          userId: any(named: 'userId'),
          currentUserId: any(named: 'currentUserId'),
        ),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.fetchFollowStats(
        userId: 'user-1',
        currentUserId: 'user-2',
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
