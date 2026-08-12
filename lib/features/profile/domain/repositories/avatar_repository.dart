import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';

/// Split out of profile CRUD — avatar upload is Storage I/O, not a
/// `profiles` row read/write, and previously reached `Supabase.instance`
/// directly from `EditProfilePage` with no repository at all.
abstract class AvatarRepository {
  /// Uploads [bytes] to the caller's own avatar slot and returns a
  /// cache-busted public URL.
  Future<Either<Failure, String>> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  });
}
