import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/hitchhiker/domain/repositories/hitchhiker_access_repository.dart';
import 'package:kumo_claude/features/hitchhiker/domain/usecases/send_hitchhiker_message_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockHitchhikerAccessRepository extends Mock
    implements HitchhikerAccessRepository {}

void main() {
  late MockHitchhikerAccessRepository mockRepo;
  late SendHitchhikerMessageUseCase useCase;

  setUp(() {
    mockRepo = MockHitchhikerAccessRepository();
    useCase = SendHitchhikerMessageUseCase(mockRepo);
  });

  test('rejects an empty message without calling the repository', () async {
    final result = await useCase(token: 'tok-1', content: '   ');

    expect(result.isLeft(), isTrue);
    verifyNever(
      () => mockRepo.sendMessage(
        token: any(named: 'token'),
        content: any(named: 'content'),
      ),
    );
  });

  test('rejects a message over 4000 characters', () async {
    final result = await useCase(token: 'tok-1', content: 'a' * 4001);

    expect(result.isLeft(), isTrue);
  });

  test('trims and delegates to the repository', () async {
    when(
      () => mockRepo.sendMessage(token: 'tok-1', content: 'hello'),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase(token: 'tok-1', content: '  hello  ');

    verify(
      () => mockRepo.sendMessage(token: 'tok-1', content: 'hello'),
    ).called(1);
    expect(result.isRight(), isTrue);
  });
}
