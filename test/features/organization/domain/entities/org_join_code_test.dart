import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_join_code.dart';
import 'package:kumo_claude/features/organization/domain/entities/org_member.dart';

void main() {
  OrgJoinCode makeCode({
    DateTime? expiresAt,
    int? maxUses,
    int usesCount = 0,
    DateTime? revokedAt,
  }) => OrgJoinCode(
    id: 'code-1',
    orgId: 'org-1',
    role: OrgMemberRole.member,
    code: 'ABC123XYZ0',
    usesCount: usesCount,
    createdBy: 'user-1',
    createdAt: DateTime.utc(2026),
    expiresAt: expiresAt,
    maxUses: maxUses,
    revokedAt: revokedAt,
  );

  group('isRevoked', () {
    test('true when revokedAt is set', () {
      expect(makeCode(revokedAt: DateTime.utc(2026, 1, 2)).isRevoked, isTrue);
    });

    test('false when revokedAt is null', () {
      expect(makeCode().isRevoked, isFalse);
    });
  });

  group('isExpired', () {
    test('true when expiresAt is in the past', () {
      final code = makeCode(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );
      expect(code.isExpired, isTrue);
    });

    test('false when expiresAt is in the future', () {
      final code = makeCode(
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
      );
      expect(code.isExpired, isFalse);
    });

    test('false when expiresAt is null (never expires)', () {
      expect(makeCode().isExpired, isFalse);
    });
  });

  group('isExhausted', () {
    test('true when usesCount reaches maxUses', () {
      final code = makeCode(maxUses: 2, usesCount: 2);
      expect(code.isExhausted, isTrue);
    });

    test('false when usesCount is below maxUses', () {
      final code = makeCode(maxUses: 2, usesCount: 1);
      expect(code.isExhausted, isFalse);
    });

    test('false when maxUses is null (unlimited)', () {
      final code = makeCode(usesCount: 1000);
      expect(code.isExhausted, isFalse);
    });
  });

  group('isActive', () {
    test('true for a fresh, unlimited, unrevoked code', () {
      expect(makeCode().isActive, isTrue);
    });

    test('false when revoked', () {
      final code = makeCode(revokedAt: DateTime.utc(2026, 1, 2));
      expect(code.isActive, isFalse);
    });

    test('false when expired', () {
      final code = makeCode(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );
      expect(code.isActive, isFalse);
    });

    test('false when exhausted', () {
      final code = makeCode(maxUses: 1, usesCount: 1);
      expect(code.isActive, isFalse);
    });
  });

  test('two codes with the same fields are equal', () {
    expect(makeCode(), makeCode());
  });

  test('codes with different codes are not equal', () {
    final a = makeCode();
    final b = OrgJoinCode(
      id: 'code-1',
      orgId: 'org-1',
      role: OrgMemberRole.member,
      code: 'DIFFERENT1',
      usesCount: 0,
      createdBy: 'user-1',
      createdAt: DateTime.utc(2026),
    );
    expect(a, isNot(b));
  });
}
