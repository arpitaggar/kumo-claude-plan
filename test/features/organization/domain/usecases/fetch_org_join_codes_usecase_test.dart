import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_join_code.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_member.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/fetch_org_join_codes_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late FetchOrgJoinCodesUseCase useCase;

  final tCode = OrgJoinCode(
    id: 'code-1',
    orgId: 'org-1',
    role: OrgMemberRole.member,
    code: 'ABC123XYZ0',
    usesCount: 0,
    createdBy: 'user-1',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = FetchOrgJoinCodesUseCase(mockRepo);
  });

  test('delegates to repository with the org id', () async {
    when(
      () => mockRepo.fetchJoinCodes('org-1'),
    ).thenAnswer((_) async => Right([tCode]));

    final result = await useCase('org-1');

    verify(() => mockRepo.fetchJoinCodes('org-1')).called(1);
    result.fold(
      (_) => fail('expected Right'),
      (codes) => expect(codes, [tCode]),
    );
  });
}
