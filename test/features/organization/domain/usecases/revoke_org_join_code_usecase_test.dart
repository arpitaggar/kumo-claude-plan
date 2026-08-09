import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/revoke_org_join_code_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late RevokeOrgJoinCodeUseCase useCase;

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = RevokeOrgJoinCodeUseCase(mockRepo);
  });

  test('delegates to repository with the code id', () async {
    when(
      () => mockRepo.revokeJoinCode('code-1'),
    ).thenAnswer((_) async => const Right(null));

    await useCase('code-1');

    verify(() => mockRepo.revokeJoinCode('code-1')).called(1);
  });

  test('propagates a ServerFailure (e.g. caller is not an admin)', () async {
    when(() => mockRepo.revokeJoinCode(any())).thenAnswer(
      (_) async => const Left(ServerFailure('Only org admins can do this')),
    );

    final result = await useCase('code-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
