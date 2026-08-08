import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/organization/domain/entities/organization.dart';

void main() {
  test('two organizations with the same fields are equal', () {
    final createdAt = DateTime.utc(2026, 1, 1);
    final a = Organization(
      id: 'org-1',
      name: 'Acme Corp',
      slug: 'acme-corp',
      ownerId: 'user-1',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final b = Organization(
      id: 'org-1',
      name: 'Acme Corp',
      slug: 'acme-corp',
      ownerId: 'user-1',
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    expect(a, b);
  });

  test('organizations with different ids are not equal', () {
    final createdAt = DateTime.utc(2026, 1, 1);
    final a = Organization(
      id: 'org-1',
      name: 'Acme Corp',
      slug: 'acme-corp',
      ownerId: 'user-1',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final b = Organization(
      id: 'org-2',
      name: 'Acme Corp',
      slug: 'acme-corp',
      ownerId: 'user-1',
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    expect(a, isNot(b));
  });
}
