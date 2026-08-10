import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/social/domain/repositories/social_repository.dart';
import 'package:kumo_claude/features/social/domain/usecases/add_post_comment_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  late MockSocialRepository mockRepo;
  late AddPostCommentUseCase useCase;

  setUp(() {
    mockRepo = MockSocialRepository();
    useCase = AddPostCommentUseCase(mockRepo);
  });

  test('delegates all fields to the repository', () async {
    when(
      () => mockRepo.addComment(
        postId: 'post-1',
        authorId: 'user-1',
        authorName: 'Alice',
        content: 'Nice trip!',
        authorAvatarUrl: 'https://example.com/a.png',
      ),
    ).thenAnswer((_) async => const Right(null));

    await useCase(
      postId: 'post-1',
      authorId: 'user-1',
      authorName: 'Alice',
      content: 'Nice trip!',
      authorAvatarUrl: 'https://example.com/a.png',
    );

    verify(
      () => mockRepo.addComment(
        postId: 'post-1',
        authorId: 'user-1',
        authorName: 'Alice',
        content: 'Nice trip!',
        authorAvatarUrl: 'https://example.com/a.png',
      ),
    ).called(1);
  });

  test('propagates failure from repository', () async {
    when(
      () => mockRepo.addComment(
        postId: any(named: 'postId'),
        authorId: any(named: 'authorId'),
        authorName: any(named: 'authorName'),
        content: any(named: 'content'),
        authorAvatarUrl: any(named: 'authorAvatarUrl'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase(
      postId: 'post-1',
      authorId: 'user-1',
      authorName: 'Alice',
      content: 'Nice trip!',
    );

    expect(result.isLeft(), isTrue);
  });
}
