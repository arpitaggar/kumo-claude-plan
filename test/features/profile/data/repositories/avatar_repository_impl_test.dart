import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/profile/data/datasources/avatar_remote_datasource.dart';
import 'package:kumo_claude/features/profile/data/repositories/avatar_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockAvatarRemoteDataSource extends Mock
    implements AvatarRemoteDataSource {}

void main() {
  late MockAvatarRemoteDataSource dataSource;
  late AvatarRepositoryImpl repository;

  final tBytes = Uint8List.fromList([1, 2, 3]);

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    dataSource = MockAvatarRemoteDataSource();
    repository = AvatarRepositoryImpl(dataSource);
  });

  group('uploadAvatar', () {
    test('returns Right(url) on success', () async {
      when(
        () => dataSource.uploadAvatar(bytes: tBytes, fileExtension: 'jpg'),
      ).thenAnswer((_) async => 'https://example.com/avatar.jpg?t=1');

      final result = await repository.uploadAvatar(
        bytes: tBytes,
        fileExtension: 'jpg',
      );

      result.fold(
        (_) => fail('expected Right'),
        (url) => expect(url, 'https://example.com/avatar.jpg?t=1'),
      );
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => dataSource.uploadAvatar(
          bytes: any(named: 'bytes'),
          fileExtension: any(named: 'fileExtension'),
        ),
      ).thenThrow(AuthException(message: 'not signed in'));

      final result = await repository.uploadAvatar(
        bytes: tBytes,
        fileExtension: 'jpg',
      );

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.uploadAvatar(
          bytes: any(named: 'bytes'),
          fileExtension: any(named: 'fileExtension'),
        ),
      ).thenThrow(ServerException(message: 'upload failed'));

      final result = await repository.uploadAvatar(
        bytes: tBytes,
        fileExtension: 'jpg',
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
