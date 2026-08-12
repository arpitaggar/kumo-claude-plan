import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/hitchhiker/domain/entities/hitchhiker_trip_view.dart';
import 'package:kumo_claude/features/hitchhiker/domain/repositories/hitchhiker_access_repository.dart';
import 'package:kumo_claude/features/hitchhiker/domain/usecases/get_hitchhiker_trip_view_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockHitchhikerAccessRepository extends Mock
    implements HitchhikerAccessRepository {}

void main() {
  late MockHitchhikerAccessRepository mockRepo;
  late GetHitchhikerTripViewUseCase useCase;

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
    mockRepo = MockHitchhikerAccessRepository();
    useCase = GetHitchhikerTripViewUseCase(mockRepo);
  });

  test('delegates to repository.getTripView with the given token', () async {
    when(
      () => mockRepo.getTripView('tok-1'),
    ).thenAnswer((_) async => Right(tView));

    await useCase('tok-1');

    verify(() => mockRepo.getTripView('tok-1')).called(1);
  });

  test('returns Right(view) on success', () async {
    when(
      () => mockRepo.getTripView(any()),
    ).thenAnswer((_) async => Right(tView));

    final result = await useCase('tok-1');

    result.fold((_) => fail('expected Right'), (v) => expect(v, tView));
  });

  test('propagates a Failure for an invalid/revoked token', () async {
    when(() => mockRepo.getTripView(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure('This collaborator link is no longer valid.'),
      ),
    );

    final result = await useCase('bad-token');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
