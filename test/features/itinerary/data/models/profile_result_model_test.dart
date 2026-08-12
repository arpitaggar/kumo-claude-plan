import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/data/models/profile_result_model.dart';

void main() {
  group('ProfileResultModel.fromRow', () {
    test('parses every field', () {
      final model = ProfileResultModel.fromRow({
        'id': 'user-1',
        'display_name': 'Alice',
        'email': 'alice@example.com',
        'avatar_url': 'https://example.com/a.png',
        'is_searchable': false,
      });

      expect(model.id, 'user-1');
      expect(model.displayName, 'Alice');
      expect(model.email, 'alice@example.com');
      expect(model.avatarUrl, 'https://example.com/a.png');
      expect(model.isSearchable, isFalse);
    });

    test(
      'defaults displayName to empty and isSearchable to true when absent',
      () {
        final model = ProfileResultModel.fromRow({
          'id': 'user-1',
          'email': 'alice@example.com',
        });

        expect(model.displayName, '');
        expect(model.isSearchable, isTrue);
        expect(model.avatarUrl, isNull);
      },
    );
  });
}
