import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/social/domain/repositories/social_repository.dart';
import 'package:kumo_claude/features/social/domain/usecases/delete_post_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  late MockSocialRepository mockRepo;
  late DeletePostUseCase useCase;

  setUp(() {
    mockRepo = MockSocialRepository();
    useCase = DeletePostUseCase(mockRepo);
  });

  test('delegates to the repository', () async {
    when(
      () => mockRepo.deletePost('post-1'),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase('post-1');

    verify(() => mockRepo.deletePost('post-1')).called(1);
    expect(result, const Right<Failure, void>(null));
  });

  test('propagates failure from repository', () async {
    when(
      () => mockRepo.deletePost(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('post-1');

    expect(result.isLeft(), isTrue);
  });
}
