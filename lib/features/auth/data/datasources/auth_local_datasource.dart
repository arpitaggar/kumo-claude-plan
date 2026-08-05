import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/error/exception.dart';
import '../models/user_model.dart';

const _kCachedUserKey = 'cached_user';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);
  Future<UserModel?> getCachedUser();
  Future<void> clearCachedUser();
}

/// Caches the signed-in user's own profile fields for offline-fallback reads
/// (see `AuthRepositoryImpl.getCurrentUser`). Backed by secure storage
/// (Android Keystore / iOS Keychain), not SharedPreferences — this cache can
/// include PII (email, phone number), which SharedPreferences stores as
/// plaintext on disk (see docs/SECURITY_AUDIT.md SEC-011).
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  const AuthLocalDataSourceImpl(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> cacheUser(UserModel user) async {
    try {
      await _storage.write(
        key: _kCachedUserKey,
        value: jsonEncode(user.toJson()),
      );
    } catch (e) {
      throw LocalStorageException.failedToSave();
    }
  }

  @override
  Future<UserModel?> getCachedUser() async {
    try {
      final json = await _storage.read(key: _kCachedUserKey);
      if (json == null) {
        return null;
      }
      return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      throw LocalStorageException.failedToRead();
    }
  }

  @override
  Future<void> clearCachedUser() async {
    try {
      await _storage.delete(key: _kCachedUserKey);
    } catch (e) {
      throw LocalStorageException.failedToDelete();
    }
  }
}
