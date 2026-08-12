import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/data/datasources/profile_remote_datasource.dart';
import 'package:kumo_claude/features/itinerary/data/models/profile_result_model.dart';
import 'package:kumo_claude/features/itinerary/data/repositories/profile_lookup_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRemoteDataSource extends Mock
    implements ProfileRemoteDataSource {}

void main() {
  late MockProfileRemoteDataSource dataSource;
  late ProfileLookupRepositoryImpl repository;

  const tProfile = ProfileResultModel(
    id: 'user-1',
    displayName: 'Alice',
    email: 'alice@example.com',
    isSearchable: true,
  );

  setUp(() {
    dataSource = MockProfileRemoteDataSource();
    repository = ProfileLookupRepositoryImpl(dataSource);
  });

  // Every method maps the same three exception types the same way
  // (AuthException -> AuthFailure, ServerException/UnexpectedException ->
  // ServerFailure) — covered once per method below.

  group('findByEmail', () {
    test('returns Right(profile) on success', () async {
      when(
        () => dataSource.findByEmail('alice@example.com'),
      ).thenAnswer((_) async => tProfile);

      final result = await repository.findByEmail('alice@example.com');

      result.fold(
        (_) => fail('expected Right'),
        (profile) => expect(profile, tProfile),
      );
    });

    test('returns Right(null) when no match', () async {
      when(() => dataSource.findByEmail(any())).thenAnswer((_) async => null);

      final result = await repository.findByEmail('nobody@example.com');

      result.fold(
        (_) => fail('expected Right'),
        (profile) => expect(profile, isNull),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.findByEmail(any()),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.findByEmail('x@y.com');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('searchByName', () {
    test('returns Right(results) on success', () async {
      when(
        () => dataSource.searchByName('ali', excludeIds: ['u2']),
      ).thenAnswer((_) async => [tProfile]);

      final result = await repository.searchByName('ali', excludeIds: ['u2']);

      result.fold(
        (_) => fail('expected Right'),
        (results) => expect(results, [tProfile]),
      );
    });

    test('maps UnexpectedException to ServerFailure', () async {
      when(
        () => dataSource.searchByName(
          any(),
          excludeIds: any(named: 'excludeIds'),
        ),
      ).thenThrow(UnexpectedException(message: 'boom'));

      final result = await repository.searchByName('ali');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('updateSearchability', () {
    test('returns Right(null) on success', () async {
      when(
        () => dataSource.updateSearchability(isSearchable: false),
      ).thenAnswer((_) async {});

      final result = await repository.updateSearchability(isSearchable: false);

      expect(result.isRight(), isTrue);
      verify(
        () => dataSource.updateSearchability(isSearchable: false),
      ).called(1);
    });

    test('maps AuthException to AuthFailure', () async {
      when(
        () => dataSource.updateSearchability(
          isSearchable: any(named: 'isSearchable'),
        ),
      ).thenThrow(AuthException(message: 'not signed in'));

      final result = await repository.updateSearchability(isSearchable: true);

      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('getCurrentUserProfile', () {
    test('returns Right(profile) on success', () async {
      when(dataSource.getCurrentUserProfile).thenAnswer((_) async => tProfile);

      final result = await repository.getCurrentUserProfile();

      result.fold(
        (_) => fail('expected Right'),
        (profile) => expect(profile, tProfile),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        dataSource.getCurrentUserProfile,
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.getCurrentUserProfile();

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('createPendingInvitation', () {
    test('returns Right(null) on success', () async {
      when(
        () => dataSource.createPendingInvitation(
          itineraryId: 'it-1',
          invitedEmail: 'x@y.com',
          role: 'viewer',
        ),
      ).thenAnswer((_) async {});

      final result = await repository.createPendingInvitation(
        itineraryId: 'it-1',
        invitedEmail: 'x@y.com',
        role: 'viewer',
      );

      expect(result.isRight(), isTrue);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => dataSource.createPendingInvitation(
          itineraryId: any(named: 'itineraryId'),
          invitedEmail: any(named: 'invitedEmail'),
          role: any(named: 'role'),
        ),
      ).thenThrow(ServerException(message: 'DB error'));

      final result = await repository.createPendingInvitation(
        itineraryId: 'it-1',
        invitedEmail: 'x@y.com',
        role: 'viewer',
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
