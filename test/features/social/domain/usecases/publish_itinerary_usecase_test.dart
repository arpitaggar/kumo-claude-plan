import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';
import 'package:kumo_claude/features/social/domain/entities/itinerary_post.dart';
import 'package:kumo_claude/features/social/domain/repositories/social_repository.dart';
import 'package:kumo_claude/features/social/domain/usecases/publish_itinerary_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  late MockSocialRepository mockRepo;
  late PublishItineraryUseCase useCase;

  final tItinerary = TravelItinerary(
    id: 'it-1',
    title: 'Tokyo Summer 2026',
    ownerId: 'user-1',
    startDate: DateTime.utc(2026, 6),
    endDate: DateTime.utc(2026, 6, 7),
    totalBudget: 2000,
    currencyCode: 'JPY',
    members: const [],
    items: const [],
    expenseSummary: const ExpenseSummary(
      totalSpent: 0,
      spentByCategory: {},
      memberBalances: {},
    ),
    createdAt: DateTime.utc(2026, 5),
    updatedAt: DateTime.utc(2026, 5),
  );

  final tPost = ItineraryPost(
    id: 'post-1',
    authorId: 'user-1',
    authorName: 'Alice',
    title: 'Tokyo Summer 2026',
    startDate: tItinerary.startDate,
    endDate: tItinerary.endDate,
    themeKey: 'classic',
    currencyCode: 'JPY',
    items: const [],
    segments: const [],
    likeCount: 0,
    likedByMe: false,
    createdAt: DateTime.utc(2026, 6, 10),
  );

  setUpAll(() {
    registerFallbackValue(tItinerary);
  });

  setUp(() {
    mockRepo = MockSocialRepository();
    useCase = PublishItineraryUseCase(mockRepo);
  });

  test('delegates to repository with the given itinerary/segments/author',
      () async {
    when(
      () => mockRepo.publishItinerary(
        itinerary: tItinerary,
        segments: const [],
        authorName: 'Alice',
      ),
    ).thenAnswer((_) async => Right(tPost));

    await useCase(
      itinerary: tItinerary,
      segments: const [],
      authorName: 'Alice',
    );

    verify(
      () => mockRepo.publishItinerary(
        itinerary: tItinerary,
        segments: const [],
        authorName: 'Alice',
      ),
    ).called(1);
  });

  test('returns Right(post) on success', () async {
    when(
      () => mockRepo.publishItinerary(
        itinerary: any(named: 'itinerary'),
        segments: any(named: 'segments'),
        authorName: any(named: 'authorName'),
        authorAvatarUrl: any(named: 'authorAvatarUrl'),
      ),
    ).thenAnswer((_) async => Right(tPost));

    final result = await useCase(
      itinerary: tItinerary,
      segments: const [],
      authorName: 'Alice',
    );

    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected Right'), (post) => expect(post.id, 'post-1'));
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.publishItinerary(
        itinerary: any(named: 'itinerary'),
        segments: any(named: 'segments'),
        authorName: any(named: 'authorName'),
        authorAvatarUrl: any(named: 'authorAvatarUrl'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase(
      itinerary: tItinerary,
      segments: const [],
      authorName: 'Alice',
    );

    expect(result.isLeft(), isTrue);
    result.fold((f) => expect(f, isA<ServerFailure>()), (_) => fail('expected Left'));
  });
}
