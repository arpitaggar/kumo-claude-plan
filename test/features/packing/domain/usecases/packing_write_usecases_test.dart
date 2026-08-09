import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/packing/domain/entities/packing_item.dart';
import 'package:kumo_claude/features/packing/domain/repositories/packing_repository.dart';
import 'package:kumo_claude/features/packing/domain/usecases/add_packing_item_usecase.dart';
import 'package:kumo_claude/features/packing/domain/usecases/delete_packing_item_usecase.dart';
import 'package:kumo_claude/features/packing/domain/usecases/toggle_packing_item_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockPackingRepository extends Mock implements PackingRepository {}

void main() {
  late MockPackingRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(
      PackingItem(
        id: '',
        itineraryId: '',
        title: '',
        isChecked: false,
        addedById: '',
        addedByName: '',
        createdAt: DateTime(2026),
      ),
    );
  });

  setUp(() {
    mockRepo = MockPackingRepository();
  });

  group('AddPackingItemUseCase', () {
    test('builds a PackingItem with a generated id and delegates to '
        'repository', () async {
      when(() => mockRepo.addItem(any())).thenAnswer(
        (invocation) async =>
            Right(invocation.positionalArguments.first as PackingItem),
      );

      final result = await AddPackingItemUseCase(mockRepo).call(
        itineraryId: 'it-1',
        title: '  Passport  ',
        addedById: 'user-1',
        addedByName: 'Alice',
        category: 'documents',
      );

      final captured =
          verify(() => mockRepo.addItem(captureAny())).captured.single
              as PackingItem;
      expect(captured.id, isNotEmpty);
      expect(captured.itineraryId, 'it-1');
      expect(captured.title, 'Passport');
      expect(captured.isChecked, isFalse);
      expect(captured.addedById, 'user-1');
      expect(captured.addedByName, 'Alice');
      expect(captured.category, 'documents');
      expect(result.isRight(), isTrue);
    });

    test('propagates ServerFailure from repository', () async {
      when(
        () => mockRepo.addItem(any()),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await AddPackingItemUseCase(mockRepo).call(
        itineraryId: 'it-1',
        title: 'Passport',
        addedById: 'user-1',
        addedByName: 'Alice',
      );

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('TogglePackingItemUseCase', () {
    test('delegates to repository with the id and checked flag', () async {
      when(
        () => mockRepo.toggleItem('item-1', isChecked: true),
      ).thenAnswer((_) async => const Right(null));

      final result = await TogglePackingItemUseCase(
        mockRepo,
      ).call('item-1', isChecked: true);

      verify(() => mockRepo.toggleItem('item-1', isChecked: true)).called(1);
      expect(result, const Right<Failure, void>(null));
    });

    test('propagates ServerFailure from repository', () async {
      when(
        () => mockRepo.toggleItem(any(), isChecked: any(named: 'isChecked')),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await TogglePackingItemUseCase(
        mockRepo,
      ).call('item-1', isChecked: false);

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('DeletePackingItemUseCase', () {
    test('delegates to repository with the given id', () async {
      when(
        () => mockRepo.deleteItem('item-1'),
      ).thenAnswer((_) async => const Right(null));

      final result = await DeletePackingItemUseCase(mockRepo).call('item-1');

      verify(() => mockRepo.deleteItem('item-1')).called(1);
      expect(result, const Right<Failure, void>(null));
    });

    test('propagates ServerFailure from repository', () async {
      when(
        () => mockRepo.deleteItem(any()),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await DeletePackingItemUseCase(mockRepo).call('item-1');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
