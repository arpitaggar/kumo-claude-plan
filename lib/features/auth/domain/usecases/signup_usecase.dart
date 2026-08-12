import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import '../validators/auth_validators.dart';

class SignupUseCase {
  const SignupUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, User>> call({
    required String email,
    required String password,
    required DateTime dateOfBirth,
    String? displayName,
  }) async {
    try {
      AuthValidators.validateEmail(email);
      AuthValidators.validatePassword(password);
      AuthValidators.validateAge18Plus(dateOfBirth);
      if (displayName != null && displayName.isNotEmpty) {
        Validators.validateNonEmpty(displayName, 'Display name');
      }
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    }
    return _repository.signUp(
      email: email,
      password: password,
      dateOfBirth: dateOfBirth,
      displayName: displayName,
    );
  }
}
