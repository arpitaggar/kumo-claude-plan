import 'package:equatable/equatable.dart';

/// Sealed failure class using pattern matching for type-safe error handling.
///
/// Failures represent domain-level errors that can be returned from
/// repositories and use cases without throwing exceptions.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// Descriptive error message.
  final String message;

  @override
  List<Object> get props => [message];
}

/// Failure when a network error occurs.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);

  factory NetworkFailure.noInternet() =>
      const NetworkFailure('No internet connection');

  factory NetworkFailure.timeout() =>
      const NetworkFailure('Request timeout (>30 seconds)');

  factory NetworkFailure.serverError(int? statusCode) =>
      NetworkFailure('Server error: ${statusCode ?? 'unknown'}');

  factory NetworkFailure.unknown() =>
      const NetworkFailure('Network error occurred');
}

/// Failure when server returns an error.
class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});
  final int? statusCode;

  @override
  List<Object> get props => [message, statusCode ?? 0];
}

/// Failure when authentication or authorization fails.
class AuthFailure extends Failure {
  const AuthFailure(super.message);

  factory AuthFailure.invalidCredentials() =>
      const AuthFailure('Invalid email or password');

  factory AuthFailure.userNotFound() => const AuthFailure('User not found');

  factory AuthFailure.sessionExpired() =>
      const AuthFailure('Session expired. Please log in again');

  factory AuthFailure.unauthorized() =>
      const AuthFailure('You do not have permission for this action');
}

/// Failure when validation fails.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);

  factory ValidationFailure.invalidEmail() =>
      const ValidationFailure('Invalid email format');

  factory ValidationFailure.passwordTooShort() =>
      const ValidationFailure('Password must be at least 8 characters');

  factory ValidationFailure.emptyField(String fieldName) =>
      ValidationFailure('$fieldName cannot be empty');
}

/// Failure when a resource is not found.
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);

  factory NotFoundFailure.resource(String resourceName) =>
      NotFoundFailure('$resourceName not found');
}

/// Failure for unexpected errors.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);

  factory UnexpectedFailure.unknown() =>
      const UnexpectedFailure('An unexpected error occurred');
}

/// Failure when local storage operations fail.
class LocalStorageFailure extends Failure {
  const LocalStorageFailure(super.message);

  factory LocalStorageFailure.failedToSave() =>
      const LocalStorageFailure('Failed to save data locally');

  factory LocalStorageFailure.failedToRead() =>
      const LocalStorageFailure('Failed to read from local storage');

  factory LocalStorageFailure.failedToDelete() =>
      const LocalStorageFailure('Failed to delete local data');
}
