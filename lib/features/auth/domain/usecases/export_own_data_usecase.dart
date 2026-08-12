import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../repositories/auth_repository.dart';

class ExportOwnDataUseCase {
  const ExportOwnDataUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, Map<String, dynamic>>> call() =>
      _repository.exportOwnData();
}
