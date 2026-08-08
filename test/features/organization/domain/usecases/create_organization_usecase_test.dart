import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/failure.dart';
import 'package:kumo_claude/features/organization/domain/entities/organization.dart';
import 'package:kumo_claude/features/organization/domain/repositories/organization_repository.dart';
import 'package:kumo_claude/features/organization/domain/usecases/create_organization_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockOrganizationRepository extends Mock implements OrganizationRepository {}

void main() {
  late MockOrganizationRepository mockRepo;
  late CreateOrganizationUseCase useCase;

  final tOrg = Organization(
    id: 'org-1',
    name: 'Acme Corp',
    slug: 'acme-corp',
    ownerId: 'user-1',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    mockRepo = MockOrganizationRepository();
    useCase = CreateOrganizationUseCase(mockRepo);
  });

  test('delegates to repository with name and slug', () async {
    when(() => mockRepo.createOrganization(name: 'Acme Corp', slug: 'acme-corp'))
        .thenAnswer((_) async => Right(tOrg));

    await useCase(name: 'Acme Corp', slug: 'acme-corp');

    verify(() => mockRepo.createOrganization(name: 'Acme Corp', slug: 'acme-corp'))
        .called(1);
  });

  test('returns the created organization on success', () async {
    when(() => mockRepo.createOrganization(
          name: any(named: 'name'),
          slug: any(named: 'slug'),
        )).thenAnswer((_) async => Right(tOrg));

    final result = await useCase(name: 'Acme Corp', slug: 'acme-corp');

    result.fold(
      (_) => fail('expected Right'),
      (org) => expect(org, tOrg),
    );
  });

  test('propagates ServerFailure from repository', () async {
    when(() => mockRepo.createOrganization(
          name: any(named: 'name'),
          slug: any(named: 'slug'),
        )).thenAnswer((_) async => const Left(ServerFailure('DB error')));

    final result = await useCase(name: 'Acme Corp', slug: 'acme-corp');

    result.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
