import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/organization.dart';
import '../repositories/organization_repository.dart';

class FetchMyOrganizationsUseCase {
  const FetchMyOrganizationsUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, List<Organization>>> call() =>
      _repository.fetchMyOrganizations();
}
