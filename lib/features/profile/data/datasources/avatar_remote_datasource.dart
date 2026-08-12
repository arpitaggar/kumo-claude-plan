import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exception.dart';
import '../../../../core/network/supabase_client.dart';

abstract class AvatarRemoteDataSource {
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  });
}

class AvatarRemoteDataSourceImpl implements AvatarRemoteDataSource {
  const AvatarRemoteDataSourceImpl();

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final userId = KumoSupabaseClient.auth.currentUser?.id;
    if (userId == null) {
      throw AuthException(message: 'Not authenticated');
    }
    try {
      final path = '$userId/avatar.$fileExtension';
      await KumoSupabaseClient.client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: sb.FileOptions(
              contentType: 'image/$fileExtension',
              upsert: true,
            ),
          );
      final publicUrl = KumoSupabaseClient.client.storage
          .from('avatars')
          .getPublicUrl(path);
      // Cache-busts the CDN/image-widget cache — same filename is reused on
      // every re-upload (one avatar slot per user), so without this a
      // freshly-uploaded image can keep showing the old cached bytes.
      return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    } on sb.StorageException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AuthException) {
        rethrow;
      }
      throw UnexpectedException(message: e.toString());
    }
  }
}
