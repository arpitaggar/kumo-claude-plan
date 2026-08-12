import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/profile_result.dart';
import 'package:kumo_claude/features/itinerary/domain/repositories/profile_lookup_repository.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/create_pending_invitation_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/find_profile_by_email_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/get_current_user_profile_result_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/search_profiles_by_name_usecase.dart';
import 'package:kumo_claude/features/itinerary/domain/usecases/update_searchability_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileLookupRepository extends Mock
    implements ProfileLookupRepository {}

void main() {
  late MockProfileLookupRepository mockRepo;

  const tProfile = ProfileResult(
    id: 'user-1',
    displayName: 'Alice',
    email: 'alice@example.com',
    isSearchable: true,
  );

  setUp(() {
    mockRepo = MockProfileLookupRepository();
  });

  group('FindProfileByEmailUseCase', () {
    test('delegates to repository and returns the result', () async {
      when(
        () => mockRepo.findByEmail('alice@example.com'),
      ).thenAnswer((_) async => const Right(tProfile));

      final result = await FindProfileByEmailUseCase(
        mockRepo,
      ).call('alice@example.com');

      expect(result, const Right<Failure, ProfileResult?>(tProfile));
      verify(() => mockRepo.findByEmail('alice@example.com')).called(1);
    });

    test('propagates failure from repository', () async {
      when(
        () => mockRepo.findByEmail(any()),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await FindProfileByEmailUseCase(mockRepo).call('x@y.com');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('SearchProfilesByNameUseCase', () {
    test('delegates query and excludeIds to repository', () async {
      when(
        () => mockRepo.searchByName('ali', excludeIds: ['u2']),
      ).thenAnswer((_) async => const Right([tProfile]));

      final result = await SearchProfilesByNameUseCase(
        mockRepo,
      ).call('ali', excludeIds: ['u2']);

      expect(result, const Right<Failure, List<ProfileResult>>([tProfile]));
      verify(() => mockRepo.searchByName('ali', excludeIds: ['u2'])).called(1);
    });

    test('propagates failure from repository', () async {
      when(
        () =>
            mockRepo.searchByName(any(), excludeIds: any(named: 'excludeIds')),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await SearchProfilesByNameUseCase(mockRepo).call('ali');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('UpdateSearchabilityUseCase', () {
    test('delegates to repository', () async {
      when(
        () => mockRepo.updateSearchability(isSearchable: false),
      ).thenAnswer((_) async => const Right(null));

      final result = await UpdateSearchabilityUseCase(
        mockRepo,
      ).call(isSearchable: false);

      expect(result, const Right<Failure, void>(null));
      verify(() => mockRepo.updateSearchability(isSearchable: false)).called(1);
    });

    test('propagates failure from repository', () async {
      when(
        () => mockRepo.updateSearchability(
          isSearchable: any(named: 'isSearchable'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await UpdateSearchabilityUseCase(
        mockRepo,
      ).call(isSearchable: true);

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('GetCurrentUserProfileResultUseCase', () {
    test('delegates to repository', () async {
      when(
        mockRepo.getCurrentUserProfile,
      ).thenAnswer((_) async => const Right(tProfile));

      final result = await GetCurrentUserProfileResultUseCase(mockRepo).call();

      expect(result, const Right<Failure, ProfileResult?>(tProfile));
      verify(mockRepo.getCurrentUserProfile).called(1);
    });

    test('propagates failure from repository', () async {
      when(
        mockRepo.getCurrentUserProfile,
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await GetCurrentUserProfileResultUseCase(mockRepo).call();

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('CreatePendingInvitationUseCase', () {
    test('delegates all fields to repository', () async {
      when(
        () => mockRepo.createPendingInvitation(
          itineraryId: 'it-1',
          invitedEmail: 'x@y.com',
          role: 'viewer',
        ),
      ).thenAnswer((_) async => const Right(null));

      final result = await CreatePendingInvitationUseCase(
        mockRepo,
      ).call(itineraryId: 'it-1', invitedEmail: 'x@y.com', role: 'viewer');

      expect(result, const Right<Failure, void>(null));
      verify(
        () => mockRepo.createPendingInvitation(
          itineraryId: 'it-1',
          invitedEmail: 'x@y.com',
          role: 'viewer',
        ),
      ).called(1);
    });

    test('propagates failure from repository', () async {
      when(
        () => mockRepo.createPendingInvitation(
          itineraryId: any(named: 'itineraryId'),
          invitedEmail: any(named: 'invitedEmail'),
          role: any(named: 'role'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

      final result = await CreatePendingInvitationUseCase(
        mockRepo,
      ).call(itineraryId: 'it-1', invitedEmail: 'x@y.com', role: 'viewer');

      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
