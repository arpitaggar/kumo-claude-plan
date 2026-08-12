import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/organization.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/redeem_org_join_code_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late RedeemOrgJoinCodeUseCase useCase;

  final tOrg = Organization(
    id: 'org-1',
    name: 'Acme Corp',
    slug: 'acme-corp',
    ownerId: 'user-1',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = RedeemOrgJoinCodeUseCase(mockRepo);
  });

  test(
    'delegates to repository with the trimmed code and returns the org',
    () async {
      when(
        () => mockRepo.redeemJoinCode('ABC123XYZ0'),
      ).thenAnswer((_) async => Right(tOrg));

      final result = await useCase('ABC123XYZ0');

      verify(() => mockRepo.redeemJoinCode('ABC123XYZ0')).called(1);
      result.fold((_) => fail('expected Right'), (org) => expect(org, tOrg));
    },
  );

  for (final message in [
    'This code is invalid',
    'This code has been revoked',
    'This code has expired',
    'This code has already been used the maximum number of times',
    'You are already a member of this organization',
  ]) {
    test(
      'passes the RPC-raised message "$message" through unchanged',
      () async {
        when(
          () => mockRepo.redeemJoinCode(any()),
        ).thenAnswer((_) async => Left(ServerFailure(message)));

        final result = await useCase('ABC123XYZ0');

        result.fold(
          (f) => expect(f.message, message),
          (_) => fail('expected Left'),
        );
      },
    );
  }
}
