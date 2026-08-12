import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/hitchhiker/data/datasources/hitchhiker_access_remote_datasource.dart';
import 'package:kumo_claude/features/hitchhiker/data/repositories/hitchhiker_access_repository_impl.dart';
import 'package:kumo_claude/features/hitchhiker/domain/entities/hitchhiker_trip_view.dart';
import 'package:mocktail/mocktail.dart';

class MockHitchhikerAccessRemoteDataSource extends Mock
    implements HitchhikerAccessRemoteDataSource {}

void main() {
  late MockHitchhikerAccessRemoteDataSource remote;
  late HitchhikerAccessRepositoryImpl repository;

  final tView = HitchhikerTripView(
    hitchhikerId: 'hh-1',
    displayName: 'Priya',
    itineraryId: 'trip-1',
    tripTitle: 'Tokyo Trip',
    tripDescription: null,
    startDate: null,
    endDate: null,
    status: 'active',
    messages: const [],
    suggestions: const [],
  );

  setUp(() {
    remote = MockHitchhikerAccessRemoteDataSource();
    repository = HitchhikerAccessRepositoryImpl(remote);
  });

  group('getTripView', () {
    test('returns Right(view) on success', () async {
      when(() => remote.getTripView('tok-1')).thenAnswer((_) async => tView);

      final result = await repository.getTripView('tok-1');

      result.fold((_) => fail('expected Right'), (v) => expect(v, tView));
    });

    test(
      'maps ServerException to ServerFailure (invalid/revoked token)',
      () async {
        when(() => remote.getTripView(any())).thenThrow(
          ServerException(
            message: 'This collaborator link is no longer valid.',
          ),
        );

        final result = await repository.getTripView('bad-token');

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );

    test('maps unexpected errors to UnexpectedFailure', () async {
      when(() => remote.getTripView(any())).thenThrow(Exception('boom'));

      final result = await repository.getTripView('tok-1');

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('sendMessage', () {
    test('returns Right(null) on success', () async {
      when(
        () => remote.sendMessage(token: 'tok-1', content: 'hi'),
      ).thenAnswer((_) async {});

      final result = await repository.sendMessage(
        token: 'tok-1',
        content: 'hi',
      );

      expect(result.isRight(), isTrue);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => remote.sendMessage(
          token: any(named: 'token'),
          content: any(named: 'content'),
        ),
      ).thenThrow(ServerException(message: 'Message cannot be empty'));

      final result = await repository.sendMessage(token: 'tok-1', content: '');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('suggestItem', () {
    test('returns Right(null) on success', () async {
      when(
        () => remote.suggestItem(
          token: 'tok-1',
          title: 'Nonna\'s',
          description: null,
        ),
      ).thenAnswer((_) async {});

      final result = await repository.suggestItem(
        token: 'tok-1',
        title: "Nonna's",
      );

      expect(result.isRight(), isTrue);
    });

    test('maps unexpected errors to UnexpectedFailure', () async {
      when(
        () => remote.suggestItem(
          token: any(named: 'token'),
          title: any(named: 'title'),
          description: any(named: 'description'),
        ),
      ).thenThrow(Exception('boom'));

      final result = await repository.suggestItem(token: 'tok-1', title: 'x');

      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
