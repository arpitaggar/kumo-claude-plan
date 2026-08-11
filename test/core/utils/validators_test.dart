import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/core/error/exception.dart';
import 'package:kumo_claude/core/utils/validators.dart';

void main() {
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
      expect(() => Validators.validateDateRange(date, date), returnsNormally);
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
      expect(() => Validators.validateNonEmpty('hello'), returnsNormally);
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
