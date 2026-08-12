import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_member.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/fetch_org_members_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late FetchOrgMembersUseCase useCase;

  final tMember = OrgMember(
    id: 'member-1',
    orgId: 'org-1',
    userId: 'user-1',
    userName: 'Alice',
    role: OrgMemberRole.admin,
    joinedAt: DateTime.utc(2026),
  );

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = FetchOrgMembersUseCase(mockRepo);
  });

  test('delegates to repository with the given orgId', () async {
    when(
      () => mockRepo.fetchOrgMembers('org-1'),
    ).thenAnswer((_) async => Right([tMember]));

    final result = await useCase('org-1');

    verify(() => mockRepo.fetchOrgMembers('org-1')).called(1);
    result.fold(
      (_) => fail('expected Right'),
      (members) => expect(members, [tMember]),
    );
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.fetchOrgMembers(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase('org-1');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
