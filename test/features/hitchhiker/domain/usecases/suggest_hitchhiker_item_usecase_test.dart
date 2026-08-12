import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/hitchhiker/domain/repositories/hitchhiker_access_repository.dart';
import 'package:kumo_claude/features/hitchhiker/domain/usecases/suggest_hitchhiker_item_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockHitchhikerAccessRepository extends Mock
    implements HitchhikerAccessRepository {}

void main() {
  late MockHitchhikerAccessRepository mockRepo;
  late SuggestHitchhikerItemUseCase useCase;

  setUp(() {
    mockRepo = MockHitchhikerAccessRepository();
    useCase = SuggestHitchhikerItemUseCase(mockRepo);
  });

  test('rejects an empty title without calling the repository', () async {
    final result = await useCase(token: 'tok-1', title: '   ');

    expect(result.isLeft(), isTrue);
    verifyNever(
      () => mockRepo.suggestItem(
        token: any(named: 'token'),
        title: any(named: 'title'),
        description: any(named: 'description'),
      ),
    );
  });

  test('rejects a title over 200 characters', () async {
    final result = await useCase(token: 'tok-1', title: 'a' * 201);

    expect(result.isLeft(), isTrue);
  });

  test('trims the title and passes description through unchanged', () async {
    when(
      () => mockRepo.suggestItem(
        token: 'tok-1',
        title: 'Dinner at Nonna\'s',
        description: 'Great pasta',
      ),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase(
      token: 'tok-1',
      title: "  Dinner at Nonna's  ",
      description: 'Great pasta',
    );

    verify(
      () => mockRepo.suggestItem(
        token: 'tok-1',
        title: "Dinner at Nonna's",
        description: 'Great pasta',
      ),
    ).called(1);
    expect(result.isRight(), isTrue);
  });

  test('allows a null description', () async {
    when(
      () => mockRepo.suggestItem(
        token: 'tok-1',
        title: 'Beach day',
        description: null,
      ),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase(token: 'tok-1', title: 'Beach day');

    expect(result.isRight(), isTrue);
  });
}
