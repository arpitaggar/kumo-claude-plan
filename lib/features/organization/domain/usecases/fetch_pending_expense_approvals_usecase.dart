import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/pending_expense_approval.dart';
import '../repositories/organization_repository.dart';

class FetchPendingExpenseApprovalsUseCase {
  const FetchPendingExpenseApprovalsUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, List<PendingExpenseApproval>>> call(String orgId) =>
      _repository.fetchPendingApprovals(orgId);
}
