import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/chat/domain/repositories/chat_repository.dart';
import 'package:kumo_claude/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late MockChatRepository mockRepo;
  late SendMessageUseCase useCase;

  setUp(() {
    mockRepo = MockChatRepository();
    useCase = SendMessageUseCase(mockRepo);
  });

  test('trims content and delegates to repository', () async {
    when(
      () => mockRepo.sendMessage(
        itineraryId: any(named: 'itineraryId'),
        senderId: any(named: 'senderId'),
        senderName: any(named: 'senderName'),
        content: any(named: 'content'),
        attachmentStoragePath: any(named: 'attachmentStoragePath'),
        attachmentUrl: any(named: 'attachmentUrl'),
        attachmentFileName: any(named: 'attachmentFileName'),
        attachmentMimeType: any(named: 'attachmentMimeType'),
        attachmentSizeBytes: any(named: 'attachmentSizeBytes'),
        attachmentKind: any(named: 'attachmentKind'),
      ),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase(
      itineraryId: 'it-1',
      senderId: 'user-1',
      senderName: 'Alice',
      content: '  Hello  ',
    );

    verify(
      () => mockRepo.sendMessage(
        itineraryId: 'it-1',
        senderId: 'user-1',
        senderName: 'Alice',
        content: 'Hello',
      ),
    ).called(1);
    expect(result, const Right<Failure, void>(null));
  });

  test('rejects empty content with no attachment', () async {
    final result = await useCase(
      itineraryId: 'it-1',
      senderId: 'user-1',
      senderName: 'Alice',
      content: '   ',
    );

    verifyNever(
      () => mockRepo.sendMessage(
        itineraryId: any(named: 'itineraryId'),
        senderId: any(named: 'senderId'),
        senderName: any(named: 'senderName'),
        content: any(named: 'content'),
      ),
    );
    result.fold(
      (f) => expect(f, isA<ValidationFailure>()),
      (_) => fail('expected Left'),
    );
  });

  test('allows empty content when an attachment is present', () async {
    when(
      () => mockRepo.sendMessage(
        itineraryId: any(named: 'itineraryId'),
        senderId: any(named: 'senderId'),
        senderName: any(named: 'senderName'),
        content: any(named: 'content'),
        attachmentStoragePath: any(named: 'attachmentStoragePath'),
        attachmentUrl: any(named: 'attachmentUrl'),
        attachmentFileName: any(named: 'attachmentFileName'),
        attachmentMimeType: any(named: 'attachmentMimeType'),
        attachmentSizeBytes: any(named: 'attachmentSizeBytes'),
        attachmentKind: any(named: 'attachmentKind'),
      ),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase(
      itineraryId: 'it-1',
      senderId: 'user-1',
      senderName: 'Alice',
      content: '',
      attachmentUrl: 'https://example.com/a.jpg',
    );

    expect(result, const Right<Failure, void>(null));
  });

  test('rejects content over 4000 characters', () async {
    final result = await useCase(
      itineraryId: 'it-1',
      senderId: 'user-1',
      senderName: 'Alice',
      content: 'a' * 4001,
    );

    result.fold(
      (f) => expect(f, isA<ValidationFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
