import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/packing/data/datasources/packing_remote_datasource.dart';
import 'package:kumo_claude/features/packing/data/models/packing_item_model.dart';
import 'package:kumo_claude/features/packing/data/repositories/packing_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockPackingRemoteDataSource extends Mock
    implements PackingRemoteDataSource {}

void main() {
  late MockPackingRemoteDataSource dataSource;
  late PackingRepositoryImpl repository;

  final tItem = PackingItemModel(
    id: 'item-1',
    itineraryId: 'it-1',
    title: 'Passport',
    isChecked: false,
    addedById: 'user-1',
    addedByName: 'Alice',
    createdAt: DateTime.utc(2026),
  );

  setUp(() {
    dataSource = MockPackingRemoteDataSource();
    repository = PackingRepositoryImpl(dataSource: dataSource);
  });

  group('watchItems', () {
    // Regression coverage: this stream used to be built with
    // `.map(Right.new).handleError((e) => Left(...))` — Stream.handleError's
    // callback return value is silently discarded, so a data-source stream
    // error used to vanish instead of ever reaching subscribers as a
    // Left(Failure). See the matching fix's comment in
    // lib/features/packing/data/repositories/packing_repository_impl.dart.
    test('maps a data-source stream to Right', () async {
      when(
        () => dataSource.watchItems('it-1'),
      ).thenAnswer((_) => Stream.value([tItem]));

      final result = await repository.watchItems('it-1').first;

      result.fold(
        (_) => fail('expected Right'),
        (items) => expect(items, [tItem]),
      );
    });

    test(
      'maps a stream error to Left(Failure) instead of dropping it',
      () async {
        when(() => dataSource.watchItems('it-1')).thenAnswer(
          (_) => Stream<List<PackingItemModel>>.error(
            ServerException(message: 'connection lost'),
          ),
        );

        final result = await repository.watchItems('it-1').first;

        result.fold(
          (f) => expect(f, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );
  });
}
