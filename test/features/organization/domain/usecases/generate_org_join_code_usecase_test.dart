import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_join_code.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_member.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/generate_org_join_code_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late GenerateOrgJoinCodeUseCase useCase;

  final tCode = OrgJoinCode(
    id: 'code-1',
    orgId: 'org-1',
    costFieldOptionId: 'option-1',
    role: OrgMemberRole.member,
    code: 'ABC123XYZ0',
    usesCount: 0,
    createdBy: 'user-1',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(OrgMemberRole.member);
  });

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = GenerateOrgJoinCodeUseCase(mockRepo);
  });

  test(
    'delegates to repository with orgId, role and optional scoping',
    () async {
      when(
        () => mockRepo.generateJoinCode(
          orgId: 'org-1',
          role: OrgMemberRole.member,
          costFieldOptionId: 'option-1',
          expiresAt: any(named: 'expiresAt'),
          maxUses: 1,
        ),
      ).thenAnswer((_) async => Right(tCode));

      await useCase(
        orgId: 'org-1',
        role: OrgMemberRole.member,
        costFieldOptionId: 'option-1',
        maxUses: 1,
      );

      verify(
        () => mockRepo.generateJoinCode(
          orgId: 'org-1',
          role: OrgMemberRole.member,
          costFieldOptionId: 'option-1',
          expiresAt: null,
          maxUses: 1,
        ),
      ).called(1);
    },
  );

  test('propagates a ServerFailure (e.g. caller is not an admin)', () async {
    when(
      () => mockRepo.generateJoinCode(
        orgId: any(named: 'orgId'),
        role: any(named: 'role'),
        costFieldOptionId: any(named: 'costFieldOptionId'),
        expiresAt: any(named: 'expiresAt'),
        maxUses: any(named: 'maxUses'),
      ),
    ).thenAnswer(
      (_) async => const Left(ServerFailure('Only org admins can do this')),
    );

    final result = await useCase(orgId: 'org-1', role: OrgMemberRole.member);

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
