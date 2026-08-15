import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/user_profile_remote_datasource.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  const UserProfileRepositoryImpl(this._remote);

  final UserProfileRemoteDataSource _remote;

  @override
  Future<Either<Failure, UserProfile>> getOwnProfile() async {
    try {
      return Right(await _remote.getOwnProfile());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on UnexpectedException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> getProfileById(String userId) async {
    try {
      return Right(await _remote.getProfileById(userId));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on UnexpectedException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? city,
    String? country,
    String? timezone,
    String? preferredCurrency,
    String? preferredLanguage,
    String? unitsPreference,
    List<String>? travelPreferenceTags,
    String? profileVisibility,
    String? contactVisibility,
    String? avatarUrl,
    bool? pushMessagePreviewEnabled,
    List<String>? enabledAccommodationSources,
  }) async {
    try {
      final result = await _remote.updateProfile(
        displayName: displayName,
        username: username,
        bio: bio,
        city: city,
        country: country,
        timezone: timezone,
        preferredCurrency: preferredCurrency,
        preferredLanguage: preferredLanguage,
        unitsPreference: unitsPreference,
        travelPreferenceTags: travelPreferenceTags,
        profileVisibility: profileVisibility,
        contactVisibility: contactVisibility,
        avatarUrl: avatarUrl,
        pushMessagePreviewEnabled: pushMessagePreviewEnabled,
        enabledAccommodationSources: enabledAccommodationSources,
      );
      return Right(result);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on UnexpectedException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
