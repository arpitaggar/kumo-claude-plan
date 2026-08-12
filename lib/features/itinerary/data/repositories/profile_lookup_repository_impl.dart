import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/profile_result.dart';
import '../../domain/repositories/profile_lookup_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileLookupRepositoryImpl implements ProfileLookupRepository {
  const ProfileLookupRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  Future<Either<Failure, ProfileResult?>> findByEmail(String email) async {
    try {
      return Right(await _remote.findByEmail(email));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on UnexpectedException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ProfileResult>>> searchByName(
    String query, {
    List<String> excludeIds = const [],
  }) async {
    try {
      return Right(await _remote.searchByName(query, excludeIds: excludeIds));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on UnexpectedException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updateSearchability({
    required bool isSearchable,
  }) async {
    try {
      await _remote.updateSearchability(isSearchable: isSearchable);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on UnexpectedException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ProfileResult?>> getCurrentUserProfile() async {
    try {
      return Right(await _remote.getCurrentUserProfile());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on UnexpectedException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> createPendingInvitation({
    required String itineraryId,
    required String invitedEmail,
    required String role,
  }) async {
    try {
      await _remote.createPendingInvitation(
        itineraryId: itineraryId,
        invitedEmail: invitedEmail,
        role: role,
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on UnexpectedException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
