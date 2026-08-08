import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/organization_repository.dart';

/// Approve/reject a submitted expense — restricted server-side (stage29's
/// `guard_expense_review_fields` trigger) to an org admin/owner of the
/// trip's organization.
class ReviewExpenseUseCase {
  const ReviewExpenseUseCase(this._repository);

  final OrganizationRepository _repository;

  Future<Either<Failure, void>> approve(String expenseId) =>
      _repository.approveExpense(expenseId);

  Future<Either<Failure, void>> reject(String expenseId, String reason) =>
      _repository.rejectExpense(expenseId, reason);
}
