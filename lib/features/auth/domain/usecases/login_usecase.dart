import 'package:dartz/dartz.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, User>> call({
    required String email,
    required String password,
  }) async {
    try {
      Validators.validateEmail(email);
      Validators.validatePassword(password);
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    }
    return _repository.login(email: email, password: password);
  }
}
