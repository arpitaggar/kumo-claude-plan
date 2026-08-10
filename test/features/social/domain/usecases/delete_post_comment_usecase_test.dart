import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/social/domain/repositories/social_repository.dart';
import 'package:kumo_claude/features/social/domain/usecases/delete_post_comment_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  late MockSocialRepository mockRepo;
  late DeletePostCommentUseCase useCase;

  setUp(() {
    mockRepo = MockSocialRepository();
    useCase = DeletePostCommentUseCase(mockRepo);
  });

  test('delegates to the repository', () async {
    when(
      () => mockRepo.deleteComment('comment-1'),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase('comment-1');

    verify(() => mockRepo.deleteComment('comment-1')).called(1);
    expect(result, const Right<Object, void>(null));
  });

  test('propagates failure from repository', () async {
    when(
      () => mockRepo.deleteComment(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('comment-1');

    expect(result.isLeft(), isTrue);
  });
}
