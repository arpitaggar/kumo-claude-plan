import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/repositories/avatar_repository.dart';
import '../datasources/avatar_remote_datasource.dart';

class AvatarRepositoryImpl implements AvatarRepository {
  const AvatarRepositoryImpl(this._remote);

  final AvatarRemoteDataSource _remote;

  @override
  Future<Either<Failure, String>> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    try {
      final url = await _remote.uploadAvatar(
        bytes: bytes,
        fileExtension: fileExtension,
      );
      return Right(url);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on UnexpectedException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
