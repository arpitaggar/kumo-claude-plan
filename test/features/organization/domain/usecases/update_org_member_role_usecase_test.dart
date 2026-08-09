import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_member.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/update_org_member_role_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late UpdateOrgMemberRoleUseCase useCase;

  setUpAll(() {
    registerFallbackValue(OrgMemberRole.member);
  });

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = UpdateOrgMemberRoleUseCase(mockRepo);
  });

  test('delegates to repository with orgMemberId and role', () async {
    when(
      () => mockRepo.updateMemberRole(
        orgMemberId: 'member-1',
        role: OrgMemberRole.admin,
      ),
    ).thenAnswer((_) async => const Right(null));

    await useCase(orgMemberId: 'member-1', role: OrgMemberRole.admin);

    verify(
      () => mockRepo.updateMemberRole(
        orgMemberId: 'member-1',
        role: OrgMemberRole.admin,
      ),
    ).called(1);
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.updateMemberRole(
        orgMemberId: any(named: 'orgMemberId'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase(
      orgMemberId: 'member-1',
      role: OrgMemberRole.member,
    );

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
