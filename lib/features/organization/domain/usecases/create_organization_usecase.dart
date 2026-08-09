import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/organization.dart';
import '../repositories/organization_repository.dart';

class CreateOrganizationUseCase {
  const CreateOrganizationUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, Organization>> call({
    required String name,
    required String slug,
  }) => _repository.createOrganization(name: name, slug: slug);
}
