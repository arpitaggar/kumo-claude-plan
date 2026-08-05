import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/social/domain/repositories/social_repository.dart';
import 'package:kumo_claude/features/social/domain/usecases/toggle_like_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  late MockSocialRepository mockRepo;
  late ToggleLikeUseCase useCase;

  setUp(() {
    mockRepo = MockSocialRepository();
    useCase = ToggleLikeUseCase(mockRepo);
  });

  test('delegates like: true to the repository', () async {
    when(
      () => mockRepo.toggleLike(postId: 'post-1', userId: 'user-1', like: true),
    ).thenAnswer((_) async => const Right(null));

    await useCase(postId: 'post-1', userId: 'user-1', like: true);

    verify(
      () => mockRepo.toggleLike(postId: 'post-1', userId: 'user-1', like: true),
    ).called(1);
  });

  test('delegates like: false to the repository', () async {
    when(
      () => mockRepo.toggleLike(postId: 'post-1', userId: 'user-1', like: false),
    ).thenAnswer((_) async => const Right(null));

    await useCase(postId: 'post-1', userId: 'user-1', like: false);

    verify(
      () => mockRepo.toggleLike(postId: 'post-1', userId: 'user-1', like: false),
    ).called(1);
  });

  test('propagates failure from repository', () async {
    when(
      () => mockRepo.toggleLike(
        postId: any(named: 'postId'),
        userId: any(named: 'userId'),
        like: any(named: 'like'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase(postId: 'post-1', userId: 'user-1', like: true);

    expect(result.isLeft(), isTrue);
  });
}
