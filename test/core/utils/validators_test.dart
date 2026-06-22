import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/utils/validators.dart';

void main() {
  group('Validators.validateEmail', () {
    test('throws ValidationException for empty email', () {
      expect(
        () => Validators.validateEmail(''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws ValidationException for null email', () {
      expect(
        () => Validators.validateEmail(null),
        throwsA(isA<ValidationException>()),
      );
    });

    test('returns true for valid email', () {
      expect(Validators.validateEmail('user@example.com'), isTrue);
    });

    test('returns true for email with subdomain', () {
      expect(Validators.validateEmail('user@mail.example.co.uk'), isTrue);
    });

    test('returns false for email without @', () {
      expect(Validators.validateEmail('notanemail'), isFalse);
    });

    test('returns false for email without domain', () {
      expect(Validators.validateEmail('user@'), isFalse);
    });

    test('returns false for email without TLD', () {
      expect(Validators.validateEmail('user@domain'), isFalse);
    });
  });

  group('Validators.validatePassword', () {
    test('throws ValidationException for empty password', () {
      expect(
        () => Validators.validatePassword(''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws ValidationException for null password', () {
      expect(
        () => Validators.validatePassword(null),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws ValidationException for password shorter than 8 chars', () {
      expect(
        () => Validators.validatePassword('short'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('returns true for valid password', () {
      expect(Validators.validatePassword('securePass123'), isTrue);
    });

    test('returns true for exactly 8 chars', () {
      expect(Validators.validatePassword('exactly8'), isTrue);
    });
  });

  group('Validators.validateCurrencyCode', () {
    test('returns true for USD', () {
      expect(Validators.validateCurrencyCode('USD'), isTrue);
    });

    test('returns true for lowercase usd', () {
      expect(Validators.validateCurrencyCode('usd'), isTrue);
    });

    test('returns true for JPY', () {
      expect(Validators.validateCurrencyCode('JPY'), isTrue);
    });

    test('returns false for unknown code', () {
      expect(Validators.validateCurrencyCode('XYZ'), isFalse);
    });

    test('returns false for null', () {
      expect(Validators.validateCurrencyCode(null), isFalse);
    });

    test('returns false for empty string', () {
      expect(Validators.validateCurrencyCode(''), isFalse);
    });
  });

  group('Validators.validateDateRange', () {
    test('does not throw for valid date range', () {
      expect(
        () => Validators.validateDateRange(
          DateTime(2026, 6),
          DateTime(2026, 6, 10),
        ),
        returnsNormally,
      );
    });

    test('does not throw for same start and end date', () {
      final date = DateTime(2026, 6);
      expect(
        () => Validators.validateDateRange(date, date),
        returnsNormally,
      );
    });

    test('throws ValidationException when start is after end', () {
      expect(
        () => Validators.validateDateRange(
          DateTime(2026, 6, 10),
          DateTime(2026, 6),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('Validators.validateNonEmpty', () {
    test('does not throw for non-empty string', () {
      expect(
        () => Validators.validateNonEmpty('hello'),
        returnsNormally,
      );
    });

    test('throws ValidationException for empty string', () {
      expect(
        () => Validators.validateNonEmpty(''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws ValidationException for whitespace-only string', () {
      expect(
        () => Validators.validateNonEmpty('   '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws ValidationException for null', () {
      expect(
        () => Validators.validateNonEmpty(null),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('Validators.validateUuid', () {
    test('returns true for valid UUID', () {
      expect(
        Validators.validateUuid('550e8400-e29b-41d4-a716-446655440000'),
        isTrue,
      );
    });

    test('returns false for invalid UUID', () {
      expect(Validators.validateUuid('not-a-uuid'), isFalse);
    });

    test('returns false for empty string', () {
      expect(Validators.validateUuid(''), isFalse);
    });

    test('returns false for null', () {
      expect(Validators.validateUuid(null), isFalse);
    });
  });
}
