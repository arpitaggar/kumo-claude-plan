import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/ratings/data/datasources/rating_remote_datasource.dart';
import 'package:kumo_claude/features/ratings/data/models/rating_model.dart';
import 'package:kumo_claude/features/ratings/data/repositories/rating_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockRatingRemoteDataSource extends Mock
    implements RatingRemoteDataSource {}

void main() {
  late MockRatingRemoteDataSource dataSource;
  late RatingRepositoryImpl repository;

  final tRating = RatingModel(
    id: 'rating-1',
    itineraryId: 'it-1',
    targetName: 'Doi Suthep',
    stars: 5,
    userId: 'user-1',
    userName: 'Alice',
    createdAt: DateTime.utc(2026),
  );

  setUp(() {
    dataSource = MockRatingRemoteDataSource();
    repository = RatingRepositoryImpl(dataSource: dataSource);
  });

  group('watchRatings', () {
    // Regression coverage: this stream used to be built with
    // `.map(Right.new).handleError((e) => Left(...))` — Stream.handleError's
    // callback return value is silently discarded, so a data-source stream
    // error used to vanish instead of ever reaching subscribers as a
    // Left(Failure). See the matching fix's comment in
    // lib/features/ratings/data/repositories/rating_repository_impl.dart.
    test('maps a data-source stream to Right', () async {
      when(
        () => dataSource.watchRatings('it-1'),
      ).thenAnswer((_) => Stream.value([tRating]));

      final result = await repository.watchRatings('it-1').first;

      result.fold(
        (_) => fail('expected Right'),
        (ratings) => expect(ratings, [tRating]),
      );
    });

    test(
      'maps a stream error to Left(Failure) instead of dropping it',
      () async {
        when(() => dataSource.watchRatings('it-1')).thenAnswer(
          (_) => Stream<List<RatingModel>>.error(
            ServerException(message: 'connection lost'),
          ),
        );

        final result = await repository.watchRatings('it-1').first;

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });
}
