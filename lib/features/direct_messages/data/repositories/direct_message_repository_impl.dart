import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../chat/domain/entities/message_read_receipt.dart';
import '../../domain/entities/direct_message.dart';
import '../../domain/entities/dm_conversation.dart';
import '../../domain/repositories/direct_message_repository.dart';
import '../datasources/direct_message_remote_datasource.dart';

class DirectMessageRepositoryImpl implements DirectMessageRepository {
  const DirectMessageRepositoryImpl({required this.remoteDataSource});

  final DirectMessageRemoteDataSource remoteDataSource;

  /// `Stream.handleError`'s callback return value is silently discarded — it
  /// only suppresses the error, it can't inject a replacement event. A
  /// `StreamTransformer` sink is the only way to turn an upstream stream
  /// error into a `Left(...)` value — matches `ChatRepositoryImpl`'s fix for
  /// the same class of bug.
  StreamTransformer<T, Either<Failure, T>> _toEither<T>() =>
      StreamTransformer.fromHandlers(
        handleData: (data, sink) => sink.add(Right(data)),
        handleError: (error, stackTrace, sink) => sink.add(
          Left(
            error is ServerException
                ? ServerFailure(error.message)
                : UnexpectedFailure(error.toString()),
          ),
        ),
      );

  @override
  Stream<Either<Failure, List<DmConversation>>> watchConversations() =>
      remoteDataSource.watchConversations().transform(_toEither());

  @override
  Stream<Either<Failure, List<DirectMessage>>> watchMessages(
    String conversationId,
  ) => remoteDataSource.watchMessages(conversationId).transform(_toEither());

  @override
  Future<Either<Failure, List<DirectMessage>>> fetchMessagesBefore({
    required String conversationId,
    required DateTime before,
    int limit = 50,
  }) async {
    try {
      final models = await remoteDataSource.fetchMessagesBefore(
        conversationId: conversationId,
        before: before,
        limit: limit,
      );
      return Right(models);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String content,
    String? attachmentStoragePath,
    String? attachmentUrl,
    String? attachmentFileName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    String? attachmentKind,
  }) async {
    try {
      await remoteDataSource.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        content: content,
        attachmentStoragePath: attachmentStoragePath,
        attachmentUrl: attachmentUrl,
        attachmentFileName: attachmentFileName,
        attachmentMimeType: attachmentMimeType,
        attachmentSizeBytes: attachmentSizeBytes,
        attachmentKind: attachmentKind,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getOrCreateConversation(
    String otherUserId,
  ) async {
    try {
      final id = await remoteDataSource.getOrCreateConversation(otherUserId);
      return Right(id);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markMessagesRead(String conversationId) async {
    try {
      await remoteDataSource.markMessagesRead(conversationId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MessageReadReceipt>>> getReadReceipts(
    String messageId,
  ) async {
    try {
      final models = await remoteDataSource.getReadReceipts(messageId);
      return Right(models);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ({String storagePath, String publicUrl})>>
  uploadAttachment({
    required Uint8List bytes,
    required String userId,
    required String fileExtension,
    required String mimeType,
  }) async {
    try {
      final result = await remoteDataSource.uploadAttachment(
        bytes: bytes,
        userId: userId,
        fileExtension: fileExtension,
        mimeType: mimeType,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> blockUser(String userId) async {
    try {
      await remoteDataSource.blockUser(userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unblockUser(String userId) async {
    try {
      await remoteDataSource.unblockUser(userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isBlockedByMe(String userId) async {
    try {
      final blocked = await remoteDataSource.isBlockedByMe(userId);
      return Right(blocked);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
