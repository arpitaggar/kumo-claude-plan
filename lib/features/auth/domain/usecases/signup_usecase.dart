import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class SignupUseCase {
  const SignupUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, User>> call({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      Validators.validateEmail(email);
      Validators.validatePassword(password);
      if (displayName != null && displayName.isNotEmpty) {
        Validators.validateNonEmpty(displayName, 'Display name');
      }
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    }
    return _repository.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }
}
