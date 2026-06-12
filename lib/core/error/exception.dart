/// Base exception class for all application exceptions.
///
/// All exceptions in Kumo inherit from this class to provide
/// consistent error handling and logging.
abstract class KumoException implements Exception {
  KumoException({required this.message, this.stackTrace});

  /// The error message describing what went wrong.
  final String message;

  /// Optional stack trace for debugging.
  final StackTrace? stackTrace;

  @override
  String toString() => 'KumoException: $message';
}

/// Exception thrown when a network request fails.
class NetworkException extends KumoException {
  NetworkException({required super.message, super.stackTrace});

  factory NetworkException.noInternet() =>
      NetworkException(message: 'No internet connection');

  factory NetworkException.timeout() =>
      NetworkException(message: 'Request timeout');

  factory NetworkException.serverError(int? statusCode) =>
      NetworkException(message: 'Server error: ${statusCode ?? 'unknown'}');
}

/// Exception thrown when authentication fails.
class AuthException extends KumoException {
  AuthException({required super.message, super.stackTrace});

  factory AuthException.invalidCredentials() =>
      AuthException(message: 'Invalid email or password');

  factory AuthException.userNotFound() =>
      AuthException(message: 'User not found');

  factory AuthException.sessionExpired() =>
      AuthException(message: 'Session expired. Please log in again');

  factory AuthException.unauthorizedAccess() =>
      AuthException(message: 'You do not have permission to access this');
}

/// Exception thrown when server returns an error.
class ServerException extends KumoException {
  ServerException({required super.message, this.statusCode, super.stackTrace});
  final int? statusCode;
}

/// Exception thrown for invalid input or validation failures.
class ValidationException extends KumoException {
  ValidationException({required super.message, super.stackTrace});

  factory ValidationException.invalidEmail() =>
      ValidationException(message: 'Invalid email format');

  factory ValidationException.passwordTooShort() =>
      ValidationException(message: 'Password must be at least 8 characters');

  factory ValidationException.emptyField(String fieldName) =>
      ValidationException(message: '$fieldName cannot be empty');
}

/// Exception thrown when a resource is not found.
class NotFoundException extends KumoException {
  NotFoundException({required super.message, super.stackTrace});

  factory NotFoundException.notFound(String resourceName) =>
      NotFoundException(message: '$resourceName not found');
}

/// Exception thrown for unexpected errors.
class UnexpectedException extends KumoException {
  UnexpectedException({required super.message, super.stackTrace});
}

/// Exception thrown when local database operations fail.
class LocalStorageException extends KumoException {
  LocalStorageException({required super.message, super.stackTrace});

  factory LocalStorageException.failedToSave() =>
      LocalStorageException(message: 'Failed to save data locally');

  factory LocalStorageException.failedToRead() =>
      LocalStorageException(message: 'Failed to read data from local storage');

  factory LocalStorageException.failedToDelete() =>
      LocalStorageException(message: 'Failed to delete local data');
}
