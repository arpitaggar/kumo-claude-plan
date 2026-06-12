import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/exception.dart';
import '../models/user_model.dart';

const _kCachedUserKey = 'cached_user';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);
  Future<UserModel?> getCachedUser();
  Future<void> clearCachedUser();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  const AuthLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<void> cacheUser(UserModel user) async {
    try {
      await _prefs.setString(_kCachedUserKey, jsonEncode(user.toJson()));
    } catch (e) {
      throw LocalStorageException.failedToSave();
    }
  }

  @override
  Future<UserModel?> getCachedUser() async {
    try {
      final json = _prefs.getString(_kCachedUserKey);
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
      await _prefs.remove(_kCachedUserKey);
    } catch (e) {
      throw LocalStorageException.failedToDelete();
    }
  }
}
