import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/profile_lookup_repository.dart';

class CreatePendingInvitationUseCase {
  const CreatePendingInvitationUseCase(this._repository);

  final ProfileLookupRepository _repository;

  Future<Either<Failure, void>> call({
    required String itineraryId,
    required String invitedEmail,
    required String role,
  }) => _repository.createPendingInvitation(
    itineraryId: itineraryId,
    invitedEmail: invitedEmail,
    role: role,
  );
}
