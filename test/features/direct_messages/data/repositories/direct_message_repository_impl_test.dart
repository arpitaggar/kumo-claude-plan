import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/direct_messages/data/datasources/direct_message_remote_datasource.dart';
import 'package:kumo_claude/features/direct_messages/data/models/direct_message_model.dart';
import 'package:kumo_claude/features/direct_messages/data/models/dm_conversation_model.dart';
import 'package:kumo_claude/features/direct_messages/data/repositories/direct_message_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockDirectMessageRemoteDataSource extends Mock
    implements DirectMessageRemoteDataSource {}

void main() {
  late MockDirectMessageRemoteDataSource dataSource;
  late DirectMessageRepositoryImpl repository;

  final tMessage = DirectMessageModel(
    id: 'msg-1',
    dmConversationId: 'conv-1',
    senderId: 'user-1',
    senderName: 'Alice',
    content: 'Hello',
    createdAt: DateTime.utc(2026),
  );

  const tConversation = DmConversationModel(
    id: 'conv-1',
    otherUserId: 'user-2',
    otherUserName: 'Bob',
  );

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    dataSource = MockDirectMessageRemoteDataSource();
    repository = DirectMessageRepositoryImpl(remoteDataSource: dataSource);
  });

  group('watchMessages', () {
    // Regression coverage for the same class of bug ChatRepositoryImpl's own
    // test guards against: Stream.handleError's callback return value is
    // silently discarded, so a naive `.map(Right.new).handleError(...)`
    // implementation would drop a data-source stream error instead of ever
    // surfacing it as a Left(Failure).
    test('maps a data-source stream to Right', () async {
      when(
        () => dataSource.watchMessages('conv-1'),
      ).thenAnswer((_) => Stream.value([tMessage]));

      final result = await repository.watchMessages('conv-1').first;

      result.fold(
        (_) => fail('expected Right'),
        (messages) => expect(messages, [tMessage]),
      );
    });

    test(
      'maps a stream error to Left(Failure) instead of dropping it',
      () async {
        when(() => dataSource.watchMessages('conv-1')).thenAnswer(
          (_) => Stream<List<DirectMessageModel>>.error(
            ServerException(message: 'connection lost'),
          ),
        );

        final result = await repository.watchMessages('conv-1').first;

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });

  group('watchConversations', () {
    test('maps a data-source stream to Right', () async {
      when(
        dataSource.watchConversations,
      ).thenAnswer((_) => Stream.value([tConversation]));

      final result = await repository.watchConversations().first;

      result.fold(
        (_) => fail('expected Right'),
        (conversations) => expect(conversations, [tConversation]),
      );
    });

    test(
      'maps a stream error to Left(Failure) instead of dropping it',
      () async {
        when(dataSource.watchConversations).thenAnswer(
          (_) => Stream<List<DmConversationModel>>.error(
            ServerException(message: 'connection lost'),
          ),
        );

        final result = await repository.watchConversations().first;

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });

  group('getOrCreateConversation', () {
    test('returns Right(conversationId) on success', () async {
      when(
        () => dataSource.getOrCreateConversation('user-2'),
      ).thenAnswer((_) async => 'conv-1');

      final result = await repository.getOrCreateConversation('user-2');

      result.fold((_) => fail('expected Right'), (id) => expect(id, 'conv-1'));
    });

    test('maps ServerException to ServerFailure (e.g. blocked)', () async {
      when(
        () => dataSource.getOrCreateConversation('user-2'),
      ).thenThrow(ServerException(message: 'You cannot message this user'));

      final result = await repository.getOrCreateConversation('user-2');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('blockUser / unblockUser / isBlockedByMe', () {
    test('blockUser returns Right(null) on success', () async {
      when(() => dataSource.blockUser('user-2')).thenAnswer((_) async {});

      final result = await repository.blockUser('user-2');

      expect(result.isRight(), isTrue);
    });

    test('unblockUser returns Right(null) on success', () async {
      when(() => dataSource.unblockUser('user-2')).thenAnswer((_) async {});

      final result = await repository.unblockUser('user-2');

      expect(result.isRight(), isTrue);
    });

    test('isBlockedByMe returns Right(true) when blocked', () async {
      when(
        () => dataSource.isBlockedByMe('user-2'),
      ).thenAnswer((_) async => true);

      final result = await repository.isBlockedByMe('user-2');

      result.fold((_) => fail('expected Right'), (blocked) {
        expect(blocked, isTrue);
      });
    });
  });

  group('uploadAttachment', () {
    final tBytes = Uint8List.fromList([1, 2, 3]);

    test('returns Right(storagePath, publicUrl) on success', () async {
      when(
        () => dataSource.uploadAttachment(
          bytes: tBytes,
          userId: 'user-1',
          fileExtension: 'jpg',
          mimeType: 'image/jpeg',
        ),
      ).thenAnswer(
        (_) async => (
          storagePath: 'user-1/abc.jpg',
          publicUrl: 'https://example.com/abc.jpg',
        ),
      );

      final result = await repository.uploadAttachment(
        bytes: tBytes,
        userId: 'user-1',
        fileExtension: 'jpg',
        mimeType: 'image/jpeg',
      );

      result.fold((_) => fail('expected Right'), (upload) {
        expect(upload.storagePath, 'user-1/abc.jpg');
        expect(upload.publicUrl, 'https://example.com/abc.jpg');
      });
    });
  });
}
