import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_member.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/invite_org_member_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late InviteOrgMemberUseCase useCase;

  final tMember = OrgMember(
    id: 'member-1',
    orgId: 'org-1',
    userId: 'user-2',
    userName: 'Bob',
    role: OrgMemberRole.member,
    joinedAt: DateTime.utc(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(OrgMemberRole.member);
  });

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = InviteOrgMemberUseCase(mockRepo);
  });

  test('delegates to repository with orgId, email and role', () async {
    when(
      () => mockRepo.inviteMember(
        orgId: 'org-1',
        email: 'bob@example.com',
        role: OrgMemberRole.member,
      ),
    ).thenAnswer((_) async => Right(tMember));

    await useCase(
      orgId: 'org-1',
      email: 'bob@example.com',
      role: OrgMemberRole.member,
    );

    verify(
      () => mockRepo.inviteMember(
        orgId: 'org-1',
        email: 'bob@example.com',
        role: OrgMemberRole.member,
      ),
    ).called(1);
  });

  test(
    'propagates NotFoundFailure when no account exists for the email',
    () async {
      when(
        () => mockRepo.inviteMember(
          orgId: any(named: 'orgId'),
          email: any(named: 'email'),
          role: any(named: 'role'),
        ),
      ).thenAnswer(
        (_) async => const Left(
          NotFoundFailure('No Kumo account found for bob@example.com'),
        ),
      );

      final result = await useCase(
        orgId: 'org-1',
        email: 'bob@example.com',
        role: OrgMemberRole.member,
      );

      result.fold(
        (f) => expect(f, isA<NotFoundFailure>()),
        (_) => fail('expected Left'),
      );
    },
  );
}
