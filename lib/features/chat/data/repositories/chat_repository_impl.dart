import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_read_receipt.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl({required this.remoteDataSource});

  final ChatRemoteDataSource remoteDataSource;

  @override
  Stream<Either<Failure, List<Message>>> watchMessages(String itineraryId) =>
      remoteDataSource
          .watchMessages(itineraryId)
          .transform(
            // `Stream.handleError`'s callback return value is silently
            // discarded — it only suppresses the error, it can't inject a
            // replacement event. A `StreamTransformer` sink is the only way to
            // turn an upstream stream error into a `Left(...)` value.
            StreamTransformer.fromHandlers(
              handleData: (data, sink) => sink.add(Right(data)),
              handleError: (error, stackTrace, sink) => sink.add(
                Left(
                  error is ServerException
                      ? ServerFailure(error.message)
                      : UnexpectedFailure(error.toString()),
                ),
              ),
            ),
          );

  @override
  Future<Either<Failure, List<Message>>> fetchMessagesBefore({
    required String itineraryId,
    required DateTime before,
    int limit = 50,
  }) async {
    try {
      final models = await remoteDataSource.fetchMessagesBefore(
        itineraryId: itineraryId,
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
    required String itineraryId,
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
        itineraryId: itineraryId,
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
  Future<Either<Failure, void>> upsertPushToken({
    required String token,
    required String platform,
  }) async {
    try {
      await remoteDataSource.upsertPushToken(token: token, platform: platform);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
