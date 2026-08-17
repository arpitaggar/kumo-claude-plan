// Regression guard for the kumo://join?joinCode=XYZ deep-link collision
// found via a real simulator smoke test (docs/Checklist.md, 2026-08-17):
// supabase_flutter's own PKCE auth-callback listener intercepts any
// incoming URI with a `code` query param regardless of host, so the
// external link's param must stay `joinCode`, never `code`, even though
// the internal /organizations/join route keeps its own `code` param.
//
// resolveJoinDeepLink() was extracted out of _RouterNotifier.redirect()
// specifically so this could be tested without a full GoRouterState/
// Riverpod harness — this app otherwise has no router tests at all, since
// _RouterNotifier itself is private/unexported.
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/config/router.dart';

void main() {
  group('resolveJoinDeepLink', () {
    test('parses joinCode from a host-form kumo://join URI', () {
      final result = resolveJoinDeepLink(
        Uri.parse('kumo://join?joinCode=ABCDEF'),
        isAuthenticated: true,
        needsAgeConfirmation: false,
      );
      expect(result, '/organizations/join?code=ABCDEF');
    });

    test('parses joinCode from a path-form kumo://join URI', () {
      // Some platforms surface a custom-scheme URI's authority as
      // uri.path instead of uri.host — both shapes must resolve the same.
      final result = resolveJoinDeepLink(
        Uri.parse('kumo:///join?joinCode=ABCDEF'),
        isAuthenticated: true,
        needsAgeConfirmation: false,
      );
      expect(result, '/organizations/join?code=ABCDEF');
    });

    test('URL-encodes a code containing special characters', () {
      final result = resolveJoinDeepLink(
        Uri.parse('kumo://join?joinCode=AB%2FCD'),
        isAuthenticated: true,
        needsAgeConfirmation: false,
      );
      expect(result, '/organizations/join?code=AB%2FCD');
    });

    test('ignores a `code` query param — the supabase_flutter collision '
        'this whole function exists to avoid', () {
      final result = resolveJoinDeepLink(
        Uri.parse('kumo://join?code=ABCDEF'),
        isAuthenticated: true,
        needsAgeConfirmation: false,
      );
      // No joinCode present, so this resolves like any code-less join
      // link: the bare manual-entry screen, not the pre-filled one. If a
      // future edit renames the param back to `code`, this assertion (not
      // "/organizations/join?code=ABCDEF") is what catches it.
      expect(result, '/organizations/join');
    });

    test('redirects to the bare manual-entry screen when no code is '
        'present', () {
      final result = resolveJoinDeepLink(
        Uri.parse('kumo://join'),
        isAuthenticated: true,
        needsAgeConfirmation: false,
      );
      expect(result, '/organizations/join');
    });

    test('redirects to the bare manual-entry screen when joinCode is '
        'empty', () {
      final result = resolveJoinDeepLink(
        Uri.parse('kumo://join?joinCode='),
        isAuthenticated: true,
        needsAgeConfirmation: false,
      );
      expect(result, '/organizations/join');
    });

    test('returns null (falls through) when not authenticated', () {
      final result = resolveJoinDeepLink(
        Uri.parse('kumo://join?joinCode=ABCDEF'),
        isAuthenticated: false,
        needsAgeConfirmation: false,
      );
      expect(result, isNull);
    });

    test('returns null (falls through) when age confirmation is still '
        'needed, even if authenticated', () {
      final result = resolveJoinDeepLink(
        Uri.parse('kumo://join?joinCode=ABCDEF'),
        isAuthenticated: true,
        needsAgeConfirmation: true,
      );
      expect(result, isNull);
    });

    test('returns null for a URI that is not a join link at all', () {
      final result = resolveJoinDeepLink(
        Uri.parse('kumo://hitchhiker?token=XYZ'),
        isAuthenticated: true,
        needsAgeConfirmation: false,
      );
      expect(result, isNull);
    });

    test('returns null for an unrelated app route', () {
      final result = resolveJoinDeepLink(
        Uri.parse('/home'),
        isAuthenticated: true,
        needsAgeConfirmation: false,
      );
      expect(result, isNull);
    });
  });
}
