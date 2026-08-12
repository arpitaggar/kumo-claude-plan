import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/organization.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/fetch_my_organizations_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late FetchMyOrganizationsUseCase useCase;

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
    useCase = FetchMyOrganizationsUseCase(mockRepo);
  });

  test('delegates to repository', () async {
    when(
      () => mockRepo.fetchMyOrganizations(),
    ).thenAnswer((_) async => Right([tOrg]));

    final result = await useCase();

    verify(() => mockRepo.fetchMyOrganizations()).called(1);
    result.fold((_) => fail('expected Right'), (orgs) => expect(orgs, [tOrg]));
  });

  test('propagates ServerFailure from repository', () async {
    when(
      () => mockRepo.fetchMyOrganizations(),
    ).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase();

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
