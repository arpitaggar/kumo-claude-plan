import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/social/domain/repositories/follow_repository.dart';
import 'package:kumo_claude/features/social/domain/usecases/toggle_follow_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  late MockFollowRepository mockRepo;
  late ToggleFollowUseCase useCase;

  setUp(() {
    mockRepo = MockFollowRepository();
    useCase = ToggleFollowUseCase(mockRepo);
  });

  test('delegates follow: true to the repository', () async {
    when(
      () => mockRepo.toggleFollow(
        followerId: 'user-1',
        followeeId: 'user-2',
        follow: true,
      ),
    ).thenAnswer((_) async => const Right(null));

    await useCase(followerId: 'user-1', followeeId: 'user-2', follow: true);

    verify(
      () => mockRepo.toggleFollow(
        followerId: 'user-1',
        followeeId: 'user-2',
        follow: true,
      ),
    ).called(1);
  });

  test('delegates follow: false (unfollow) to the repository', () async {
    when(
      () => mockRepo.toggleFollow(
        followerId: 'user-1',
        followeeId: 'user-2',
        follow: false,
      ),
    ).thenAnswer((_) async => const Right(null));

    await useCase(followerId: 'user-1', followeeId: 'user-2', follow: false);

    verify(
      () => mockRepo.toggleFollow(
        followerId: 'user-1',
        followeeId: 'user-2',
        follow: false,
      ),
    ).called(1);
  });

  test('propagates failure from repository', () async {
    when(
      () => mockRepo.toggleFollow(
        followerId: any(named: 'followerId'),
        followeeId: any(named: 'followeeId'),
        follow: any(named: 'follow'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase(
      followerId: 'user-1',
      followeeId: 'user-2',
      follow: true,
    );

    expect(result.isLeft(), isTrue);
  });
}
