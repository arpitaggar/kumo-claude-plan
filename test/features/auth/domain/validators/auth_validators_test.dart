import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/features/auth/domain/validators/auth_validators.dart';

void main() {
  group('AuthValidators.validateEmail', () {
    test('throws ValidationException for empty email', () {
      expect(
        () => AuthValidators.validateEmail(''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws ValidationException for null email', () {
      expect(
        () => AuthValidators.validateEmail(null),
        throwsA(isA<ValidationException>()),
      );
    });

    test('returns true for valid email', () {
      expect(AuthValidators.validateEmail('user@example.com'), isTrue);
    });

    test('returns true for email with subdomain', () {
      expect(AuthValidators.validateEmail('user@mail.example.co.uk'), isTrue);
    });

    test('returns false for email without @', () {
      expect(AuthValidators.validateEmail('notanemail'), isFalse);
    });

    test('returns false for email without domain', () {
      expect(AuthValidators.validateEmail('user@'), isFalse);
    });

    test('returns false for email without TLD', () {
      expect(AuthValidators.validateEmail('user@domain'), isFalse);
    });
  });

  group('AuthValidators.validatePassword', () {
    test('throws ValidationException for empty password', () {
      expect(
        () => AuthValidators.validatePassword(''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws ValidationException for null password', () {
      expect(
        () => AuthValidators.validatePassword(null),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws ValidationException for password shorter than 8 chars', () {
      expect(
        () => AuthValidators.validatePassword('short'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('returns true for valid password', () {
      expect(AuthValidators.validatePassword('securePass123'), isTrue);
    });

    test('returns true for exactly 8 chars', () {
      expect(AuthValidators.validatePassword('exactly8'), isTrue);
    });
  });
}
