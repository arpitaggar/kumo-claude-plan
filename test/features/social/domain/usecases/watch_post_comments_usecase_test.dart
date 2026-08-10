import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/social/domain/entities/post_comment.dart';
import 'package:kumo_claude/features/social/domain/repositories/social_repository.dart';
import 'package:kumo_claude/features/social/domain/usecases/watch_post_comments_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  test('delegates to the repository with the given postId', () async {
    final mockRepo = MockSocialRepository();
    final useCase = WatchPostCommentsUseCase(mockRepo);
    when(
      () => mockRepo.watchComments('post-1'),
    ).thenAnswer((_) => Stream.value(const Right([])));

    final result = await useCase('post-1').first;

    verify(() => mockRepo.watchComments('post-1')).called(1);
    expect(result, const Right<Object, List<PostComment>>([]));
  });
}
