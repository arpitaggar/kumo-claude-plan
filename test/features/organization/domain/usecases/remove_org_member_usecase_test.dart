import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/remove_org_member_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late RemoveOrgMemberUseCase useCase;

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = RemoveOrgMemberUseCase(mockRepo);
  });

  test('delegates to repository with the provided id', () async {
    when(
      () => mockRepo.removeMember('member-1'),
    ).thenAnswer((_) async => const Right(null));

    await useCase('member-1');

    verify(() => mockRepo.removeMember('member-1')).called(1);
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.removeMember(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('member-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
