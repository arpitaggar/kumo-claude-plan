import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import '../entities/travel_itinerary.dart';
import '../repositories/itinerary_repository.dart';

class CreateItineraryUseCase {
  const CreateItineraryUseCase(this._repository);

  final ItineraryRepository _repository;

  Future<Either<Failure, TravelItinerary>> call({
    required String title,
    required String ownerId,
    required String ownerName,
    required DateTime startDate,
    required DateTime endDate,
    required double totalBudget,
    required String currencyCode,
    String? description,
    List<ItineraryItem>? items,
  }) async {
    try {
      Validators.validateNonEmpty(title, 'Title');
      Validators.validateDateRange(startDate, endDate);
      Validators.validateAmount(totalBudget, 'Budget');
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    }

    final now = DateTime.now().toUtc();
    final itinerary = TravelItinerary(
      id: const Uuid().v4(),
      title: title.trim(),
      ownerId: ownerId,
      startDate: startDate,
      endDate: endDate,
      totalBudget: totalBudget,
      currencyCode: currencyCode,
      members: [
        GroupMember(
          userId: ownerId,
          userName: ownerName,
          role: GroupMemberRole.owner,
          joinedAt: now,
        ),
      ],
      items: items ?? const [],
      expenseSummary: const ExpenseSummary(
        totalSpent: 0,
        spentByCategory: {},
        memberBalances: {},
      ),
      createdAt: now,
      updatedAt: now,
      description: description,
    );

    return _repository.createItinerary(itinerary);
  }
}
