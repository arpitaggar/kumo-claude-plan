import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/social/domain/repositories/social_repository.dart';
import 'package:kumo_claude/features/social/domain/usecases/fork_post_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  late MockSocialRepository mockRepo;
  late ForkPostUseCase useCase;

  final tForked = TravelItinerary(
    id: 'it-2',
    title: 'Tokyo Summer 2026',
    ownerId: 'user-2',
    startDate: DateTime.utc(2026, 6),
    endDate: DateTime.utc(2026, 6, 7),
    totalBudget: 0,
    currencyCode: 'JPY',
    members: const [],
    items: const [],
    expenseSummary: const ExpenseSummary(
      totalSpent: 0,
      spentByCategory: {},
      memberBalances: {},
    ),
    createdAt: DateTime.utc(2026, 6, 12),
    updatedAt: DateTime.utc(2026, 6, 12),
    originPostId: 'post-1',
  );

  setUp(() {
    mockRepo = MockSocialRepository();
    useCase = ForkPostUseCase(mockRepo);
  });

  test('delegates to repository with postId/newOwnerId/newOwnerName', () async {
    when(
      () => mockRepo.forkPost(
        postId: 'post-1',
        newOwnerId: 'user-2',
        newOwnerName: 'Bob',
      ),
    ).thenAnswer((_) async => Right(tForked));

    await useCase(postId: 'post-1', newOwnerId: 'user-2', newOwnerName: 'Bob');

    verify(
      () => mockRepo.forkPost(
        postId: 'post-1',
        newOwnerId: 'user-2',
        newOwnerName: 'Bob',
      ),
    ).called(1);
  });

  test('returns Right(itinerary) with originPostId set on success', () async {
    when(
      () => mockRepo.forkPost(
        postId: any(named: 'postId'),
        newOwnerId: any(named: 'newOwnerId'),
        newOwnerName: any(named: 'newOwnerName'),
      ),
    ).thenAnswer((_) async => Right(tForked));

    final result = await useCase(
      postId: 'post-1',
      newOwnerId: 'user-2',
      newOwnerName: 'Bob',
    );

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('expected Right'),
      (itinerary) => expect(itinerary.originPostId, 'post-1'),
    );
  });

  test('propagates NotFoundFailure when the post no longer exists', () async {
    when(
      () => mockRepo.forkPost(
        postId: any(named: 'postId'),
        newOwnerId: any(named: 'newOwnerId'),
        newOwnerName: any(named: 'newOwnerName'),
      ),
    ).thenAnswer((_) async => const Left(NotFoundFailure('Post not found')));

    final result = await useCase(
      postId: 'gone',
      newOwnerId: 'user-2',
      newOwnerName: 'Bob',
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<NotFoundFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
