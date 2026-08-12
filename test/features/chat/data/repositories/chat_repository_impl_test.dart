import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:kumo_claude/features/chat/data/models/message_model.dart';
import 'package:kumo_claude/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRemoteDataSource extends Mock implements ChatRemoteDataSource {}

void main() {
  late MockChatRemoteDataSource dataSource;
  late ChatRepositoryImpl repository;

  final tMessage = MessageModel(
    id: 'msg-1',
    itineraryId: 'it-1',
    senderId: 'user-1',
    senderName: 'Alice',
    content: 'Hello',
    createdAt: DateTime.utc(2026),
  );

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    dataSource = MockChatRemoteDataSource();
    repository = ChatRepositoryImpl(remoteDataSource: dataSource);
  });

  group('watchMessages', () {
    // Regression coverage: this stream used to be built with
    // `.map(Right.new).handleError((e) => Left(...))` — Stream.handleError's
    // callback return value is silently discarded, so a data-source stream
    // error used to vanish instead of ever reaching subscribers as a
    // Left(Failure). See the matching fix's comment in
    // lib/features/chat/data/repositories/chat_repository_impl.dart.
    test('maps a data-source stream to Right', () async {
      when(
        () => dataSource.watchMessages('it-1'),
      ).thenAnswer((_) => Stream.value([tMessage]));

      final result = await repository.watchMessages('it-1').first;

      result.fold(
        (_) => fail('expected Right'),
        (messages) => expect(messages, [tMessage]),
      );
    });

    test(
      'maps a stream error to Left(Failure) instead of dropping it',
      () async {
        when(() => dataSource.watchMessages('it-1')).thenAnswer(
          (_) => Stream<List<MessageModel>>.error(
            ServerException(message: 'connection lost'),
          ),
        );

        final result = await repository.watchMessages('it-1').first;

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
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

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.uploadAttachment(
          bytes: any(named: 'bytes'),
          userId: any(named: 'userId'),
          fileExtension: any(named: 'fileExtension'),
          mimeType: any(named: 'mimeType'),
        ),
      ).thenThrow(ServerException(message: 'upload failed'));

      final result = await repository.uploadAttachment(
        bytes: tBytes,
        userId: 'user-1',
        fileExtension: 'jpg',
        mimeType: 'image/jpeg',
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
