import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/hitchhiker/data/datasources/hitchhiker_remote_datasource.dart';
import 'package:kumo_claude/features/hitchhiker/data/models/hitchhiker_model.dart';
import 'package:kumo_claude/features/hitchhiker/data/repositories/hitchhiker_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockHitchhikerRemoteDataSource extends Mock
    implements HitchhikerRemoteDataSource {}

void main() {
  late MockHitchhikerRemoteDataSource remote;
  late HitchhikerRepositoryImpl repository;

  final tHitchhiker = HitchhikerModel(
    id: 'hh-1',
    itineraryId: 'trip-1',
    displayName: 'Priya',
    accessToken: 'token-abc',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    remote = MockHitchhikerRemoteDataSource();
    repository = HitchhikerRepositoryImpl(remote);
  });

  group('createHitchhiker', () {
    test('returns Right(hitchhiker) on success', () async {
      when(
        () => remote.createHitchhiker(
          itineraryId: 'trip-1',
          displayName: 'Priya',
        ),
      ).thenAnswer((_) async => tHitchhiker);

      final result = await repository.createHitchhiker(
        itineraryId: 'trip-1',
        displayName: 'Priya',
      );

      result.fold((_) => fail('expected Right'), (h) => expect(h, tHitchhiker));
    });

    test('maps AuthException to AuthFailure (not the trip owner)', () async {
      when(
        () => remote.createHitchhiker(
          itineraryId: any(named: 'itineraryId'),
          displayName: any(named: 'displayName'),
        ),
      ).thenThrow(
        AuthException(message: 'Only the trip owner can add a Hitchhiker'),
      );

      final result = await repository.createHitchhiker(
        itineraryId: 'trip-1',
        displayName: 'Priya',
      );

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => remote.createHitchhiker(
          itineraryId: any(named: 'itineraryId'),
          displayName: any(named: 'displayName'),
        ),
      ).thenThrow(ServerException(message: 'Name must be 1-60 characters'));

      final result = await repository.createHitchhiker(
        itineraryId: 'trip-1',
        displayName: 'Priya',
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('revokeHitchhiker', () {
    test('returns Right(null) on success', () async {
      when(() => remote.revokeHitchhiker('hh-1')).thenAnswer((_) async {});

      final result = await repository.revokeHitchhiker('hh-1');

      expect(result.isRight(), isTrue);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => remote.revokeHitchhiker(any()),
      ).thenThrow(ServerException(message: 'Hitchhiker not found'));

      final result = await repository.revokeHitchhiker('hh-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('listHitchhikers', () {
    test('returns Right(list) on success', () async {
      when(
        () => remote.listHitchhikers('trip-1'),
      ).thenAnswer((_) async => [tHitchhiker]);

      final result = await repository.listHitchhikers('trip-1');

      result.fold(
        (_) => fail('expected Right'),
        (list) => expect(list, [tHitchhiker]),
      );
    });

    test('maps unexpected errors to UnexpectedFailure', () async {
      when(() => remote.listHitchhikers(any())).thenThrow(Exception('boom'));

      final result = await repository.listHitchhikers('trip-1');

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
