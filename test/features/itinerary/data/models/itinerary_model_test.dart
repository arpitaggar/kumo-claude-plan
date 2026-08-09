import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/data/models/itinerary_model.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/travel_itinerary.dart';

void main() {
  // ── GroupMemberModel ────────────────────────────────────────────────────────

  group('GroupMemberModel.fromJson — dual key format', () {
    final joinedAt = DateTime.utc(2026, 6).toIso8601String();

    test('parses snake_case keys (Flutter client format)', () {
      final json = {
        'user_id': 'uid-1',
        'user_name': 'Alice',
        'role': 'editor',
        'joined_at': joinedAt,
      };
      final member = GroupMemberModel.fromJson(json);
      expect(member.userId, 'uid-1');
      expect(member.userName, 'Alice');
      expect(member.role, GroupMemberRole.editor);
    });

    test('parses camelCase keys (Postgres trigger format)', () {
      final json = {
        'userId': 'uid-2',
        'userName': 'Bob',
        'role': 'viewer',
        'joinedAt': joinedAt,
      };
      final member = GroupMemberModel.fromJson(json);
      expect(member.userId, 'uid-2');
      expect(member.userName, 'Bob');
      expect(member.role, GroupMemberRole.viewer);
    });

    test('snake_case takes precedence when both keys present', () {
      final json = {
        'user_id': 'snake-uid',
        'userId': 'camel-uid',
        'user_name': 'Carol',
        'userName': 'Carol-camel',
        'role': 'viewer',
        'joined_at': joinedAt,
        'joinedAt': joinedAt,
      };
      final member = GroupMemberModel.fromJson(json);
      expect(member.userId, 'snake-uid');
      expect(member.userName, 'Carol');
    });

    test(
      'defaults userName to empty string when both name keys are absent',
      () {
        final json = {
          'user_id': 'uid-3',
          'role': 'viewer',
          'joined_at': joinedAt,
        };
        final member = GroupMemberModel.fromJson(json);
        expect(member.userName, '');
      },
    );

    test('defaults role to viewer for unrecognised role string', () {
      final json = {
        'user_id': 'uid-4',
        'user_name': 'Dave',
        'role': 'superadmin',
        'joined_at': joinedAt,
      };
      final member = GroupMemberModel.fromJson(json);
      expect(member.role, GroupMemberRole.viewer);
    });

    test('toJson always writes snake_case keys', () {
      final json = {
        'user_id': 'uid-5',
        'user_name': 'Eve',
        'role': 'editor',
        'joined_at': joinedAt,
      };
      final out = GroupMemberModel.fromJson(json).toJson();
      expect(out.containsKey('user_id'), isTrue);
      expect(out.containsKey('userId'), isFalse);
    });
  });

  // ── ItineraryModel ──────────────────────────────────────────────────────────

  group('ItineraryModel.fromJson — themeKey', () {
    Map<String, dynamic> baseJson() => {
      'id': 'itin-1',
      'title': 'Tokyo Trip',
      'owner_id': 'owner-uid',
      'start_date': '2026-06-10T00:00:00.000Z',
      'end_date': '2026-06-15T00:00:00.000Z',
      'total_budget': 2000.0,
      'currency_code': 'USD',
      'members': <dynamic>[],
      'items': <dynamic>[],
      'expense_summary': {
        'total_spent': 0,
        'spent_by_category': <String, dynamic>{},
        'member_balances': <String, dynamic>{},
      },
      'created_at': '2026-06-01T00:00:00.000Z',
      'updated_at': '2026-06-01T00:00:00.000Z',
      'status': 'draft',
      'is_public': false,
    };

    test('reads theme_key from JSON', () {
      final json = baseJson()..['theme_key'] = 'sakura';
      final model = ItineraryModel.fromJson(json);
      expect(model.themeKey, 'sakura');
    });

    test('defaults themeKey to classic when key is absent', () {
      final model = ItineraryModel.fromJson(baseJson());
      expect(model.themeKey, 'classic');
    });

    test('defaults themeKey to classic when value is null', () {
      final json = baseJson()..['theme_key'] = null;
      final model = ItineraryModel.fromJson(json);
      expect(model.themeKey, 'classic');
    });

    test('toJson includes theme_key', () {
      final json = baseJson()..['theme_key'] = 'tropical';
      final model = ItineraryModel.fromJson(json);
      expect(model.toJson()['theme_key'], 'tropical');
    });

    test('fromEntity preserves themeKey', () {
      final json = baseJson()..['theme_key'] = 'alpine';
      final source = ItineraryModel.fromJson(json);
      final copy = ItineraryModel.fromEntity(source);
      expect(copy.themeKey, 'alpine');
    });
  });

  group('ItineraryModel — originPostId (Stage 22 social feed)', () {
    Map<String, dynamic> baseJson() => {
      'id': 'itin-1',
      'title': 'Tokyo Trip',
      'owner_id': 'owner-uid',
      'start_date': '2026-06-10T00:00:00.000Z',
      'end_date': '2026-06-15T00:00:00.000Z',
      'total_budget': 2000.0,
      'currency_code': 'USD',
      'members': <dynamic>[],
      'items': <dynamic>[],
      'expense_summary': {
        'total_spent': 0,
        'spent_by_category': <String, dynamic>{},
        'member_balances': <String, dynamic>{},
      },
      'created_at': '2026-06-01T00:00:00.000Z',
      'updated_at': '2026-06-01T00:00:00.000Z',
      'status': 'draft',
      'is_public': false,
    };

    test('reads origin_post_id from JSON when present', () {
      final json = baseJson()..['origin_post_id'] = 'post-1';
      final model = ItineraryModel.fromJson(json);
      expect(model.originPostId, 'post-1');
    });

    test('defaults originPostId to null when key is absent', () {
      final model = ItineraryModel.fromJson(baseJson());
      expect(model.originPostId, isNull);
    });

    test('toJson omits origin_post_id when null', () {
      final model = ItineraryModel.fromJson(baseJson());
      expect(model.toJson().containsKey('origin_post_id'), isFalse);
    });

    test('toJson includes origin_post_id when set', () {
      final json = baseJson()..['origin_post_id'] = 'post-2';
      final model = ItineraryModel.fromJson(json);
      expect(model.toJson()['origin_post_id'], 'post-2');
    });

    test('fromEntity preserves originPostId', () {
      final json = baseJson()..['origin_post_id'] = 'post-3';
      final source = ItineraryModel.fromJson(json);
      final copy = ItineraryModel.fromEntity(source);
      expect(copy.originPostId, 'post-3');
    });

    test('copyWith updates originPostId (used by ForkPostUseCase)', () {
      final model = ItineraryModel.fromJson(baseJson());
      final forked = model.copyWith(originPostId: 'post-4');
      expect(forked.originPostId, 'post-4');
      expect(
        model.originPostId,
        isNull,
        reason: 'copyWith must not mutate the original',
      );
    });
  });
}
