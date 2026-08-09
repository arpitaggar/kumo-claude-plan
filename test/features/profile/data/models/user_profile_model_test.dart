import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/profile/data/models/user_profile_model.dart';

void main() {
  group('UserProfileModel.fromJson', () {
    test('parses a full row', () {
      final model = UserProfileModel.fromJson({
        'id': 'user-1',
        'email': 'me@example.com',
        'display_name': 'Alice',
        'username': 'alice',
        'avatar_url': 'https://example.com/a.png',
        'bio': 'Traveler',
        'city': 'Chiang Mai',
        'country': 'Thailand',
        'timezone': 'Asia/Bangkok',
        'preferred_currency': 'THB',
        'preferred_language': 'en',
        'units_preference': 'imperial',
        'travel_preference_tags': ['adventure', 'food'],
        'profile_visibility': 'private',
        'contact_visibility': 'public',
        'is_searchable': false,
        'username_last_changed_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-06-01T00:00:00.000Z',
        'push_message_preview_enabled': true,
      });

      expect(model.id, 'user-1');
      expect(model.email, 'me@example.com');
      expect(model.displayName, 'Alice');
      expect(model.username, 'alice');
      expect(model.travelPreferenceTags, ['adventure', 'food']);
      expect(model.unitsPreference, 'imperial');
      expect(model.profileVisibility, 'private');
      expect(model.contactVisibility, 'public');
      expect(model.isSearchable, isFalse);
      expect(
        model.usernameLastChangedAt,
        DateTime.parse('2026-01-01T00:00:00.000Z'),
      );
      expect(model.updatedAt, DateTime.parse('2026-06-01T00:00:00.000Z'));
      expect(model.pushMessagePreviewEnabled, isTrue);
    });

    test('defaults email/displayName to empty string when absent — e.g. '
        "getProfileById's restricted column set for another user's profile "
        '(SEC-008)', () {
      final model = UserProfileModel.fromJson({
        'id': 'user-1',
        'updated_at': '2026-06-01T00:00:00.000Z',
      });

      expect(model.email, '');
      expect(model.displayName, '');
    });

    test('defaults unitsPreference/profileVisibility/contactVisibility/'
        'isSearchable/pushMessagePreviewEnabled when absent', () {
      final model = UserProfileModel.fromJson({
        'id': 'user-1',
        'updated_at': '2026-06-01T00:00:00.000Z',
      });

      expect(model.unitsPreference, 'metric');
      expect(model.profileVisibility, 'public');
      expect(model.contactVisibility, 'collaborators_only');
      expect(model.isSearchable, isTrue);
      expect(model.pushMessagePreviewEnabled, isFalse);
    });

    test('defaults travelPreferenceTags to an empty list when absent or not '
        'a List', () {
      final model = UserProfileModel.fromJson({
        'id': 'user-1',
        'updated_at': '2026-06-01T00:00:00.000Z',
      });

      expect(model.travelPreferenceTags, isEmpty);
    });

    test('defaults usernameLastChangedAt to null when absent', () {
      final model = UserProfileModel.fromJson({
        'id': 'user-1',
        'updated_at': '2026-06-01T00:00:00.000Z',
      });

      expect(model.usernameLastChangedAt, isNull);
    });

    test('defaults updatedAt to now() when absent', () {
      final before = DateTime.now();
      final model = UserProfileModel.fromJson({'id': 'user-1'});
      final after = DateTime.now();

      expect(
        model.updatedAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        model.updatedAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('leaves nullable optional fields null when absent', () {
      final model = UserProfileModel.fromJson({
        'id': 'user-1',
        'updated_at': '2026-06-01T00:00:00.000Z',
      });

      expect(model.username, isNull);
      expect(model.avatarUrl, isNull);
      expect(model.bio, isNull);
      expect(model.city, isNull);
      expect(model.country, isNull);
      expect(model.timezone, isNull);
      expect(model.preferredCurrency, isNull);
      expect(model.preferredLanguage, isNull);
    });
  });
}
