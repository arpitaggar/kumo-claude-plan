import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/auth/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  group('UserModel.fromSupabaseUser', () {
    test('maps every field from a fully-populated Supabase user', () {
      const supabaseUser = sb.User(
        id: 'user-1',
        appMetadata: {},
        userMetadata: {
          'display_name': 'Alice',
          'avatar_url': 'https://example.com/a.png',
        },
        aud: 'authenticated',
        email: 'alice@example.com',
        phone: '+15551234567',
        createdAt: '2026-01-01T00:00:00.000Z',
        lastSignInAt: '2026-06-01T00:00:00.000Z',
        emailConfirmedAt: '2026-01-02T00:00:00.000Z',
      );

      final model = UserModel.fromSupabaseUser(supabaseUser);

      expect(model.id, 'user-1');
      expect(model.email, 'alice@example.com');
      expect(model.displayName, 'Alice');
      expect(model.avatarUrl, 'https://example.com/a.png');
      expect(model.phoneNumber, '+15551234567');
      expect(model.emailVerified, isTrue);
      expect(model.createdAt, DateTime.parse('2026-01-01T00:00:00.000Z'));
      expect(model.lastSignInAt, DateTime.parse('2026-06-01T00:00:00.000Z'));
    });

    test('defaults displayName/avatarUrl to null and emailVerified to false '
        'when absent', () {
      const supabaseUser = sb.User(
        id: 'user-1',
        appMetadata: {},
        userMetadata: null,
        aud: 'authenticated',
        email: 'alice@example.com',
        createdAt: '2026-01-01T00:00:00.000Z',
      );

      final model = UserModel.fromSupabaseUser(supabaseUser);

      expect(model.displayName, isNull);
      expect(model.avatarUrl, isNull);
      expect(model.lastSignInAt, isNull);
      expect(model.emailVerified, isFalse);
    });

    test('defaults email to empty string when Supabase gives none', () {
      const supabaseUser = sb.User(
        id: 'user-1',
        appMetadata: {},
        userMetadata: null,
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00.000Z',
      );

      final model = UserModel.fromSupabaseUser(supabaseUser);

      expect(model.email, '');
    });
  });

  group('UserModel.fromJson', () {
    final fullJson = <String, dynamic>{
      'id': 'user-1',
      'email': 'alice@example.com',
      'created_at': '2026-01-01T00:00:00.000Z',
      'display_name': 'Alice',
      'avatar_url': 'https://example.com/a.png',
      'last_sign_in_at': '2026-06-01T00:00:00.000Z',
      'email_verified': true,
      'phone_number': '+15551234567',
      'mfa_enabled': true,
    };

    test('parses every field', () {
      final model = UserModel.fromJson(fullJson);

      expect(model.id, 'user-1');
      expect(model.email, 'alice@example.com');
      expect(model.displayName, 'Alice');
      expect(model.avatarUrl, 'https://example.com/a.png');
      expect(model.phoneNumber, '+15551234567');
      expect(model.emailVerified, isTrue);
      expect(model.mfaEnabled, isTrue);
      expect(model.lastSignInAt, DateTime.parse('2026-06-01T00:00:00.000Z'));
    });

    test('defaults emailVerified/mfaEnabled to false and lastSignInAt to null '
        'when absent', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..remove('email_verified')
        ..remove('mfa_enabled')
        ..remove('last_sign_in_at');

      final model = UserModel.fromJson(json);

      expect(model.emailVerified, isFalse);
      expect(model.mfaEnabled, isFalse);
      expect(model.lastSignInAt, isNull);
    });
  });

  group('UserModel.toJson', () {
    test('round-trips through fromJson', () {
      final original = UserModel.fromJson(const {
        'id': 'user-1',
        'email': 'alice@example.com',
        'created_at': '2026-01-01T00:00:00.000Z',
        'display_name': 'Alice',
        'avatar_url': 'https://example.com/a.png',
        'last_sign_in_at': '2026-06-01T00:00:00.000Z',
        'email_verified': true,
        'phone_number': '+15551234567',
        'mfa_enabled': false,
      });

      final roundTripped = UserModel.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.email, original.email);
      expect(roundTripped.displayName, original.displayName);
      expect(roundTripped.avatarUrl, original.avatarUrl);
      expect(roundTripped.phoneNumber, original.phoneNumber);
      expect(roundTripped.emailVerified, original.emailVerified);
      expect(roundTripped.createdAt, original.createdAt);
      expect(roundTripped.lastSignInAt, original.lastSignInAt);
    });
  });
}
