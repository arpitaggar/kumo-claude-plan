import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/features/itinerary/domain/entities/trip_theme.dart';

void main() {
  group('TripTheme.forKey', () {
    test('returns correct preset for every defined key', () {
      const keys = [
        'classic',
        'sakura',
        'tropical',
        'alpine',
        'desert',
        'nordic',
        'mediterranean',
        'rainforest',
      ];
      for (final key in keys) {
        final theme = TripTheme.forKey(key);
        expect(theme.key, key, reason: 'expected key $key');
      }
    });

    test('falls back to classic for an unknown key', () {
      expect(TripTheme.forKey('unknown').key, 'classic');
    });

    test('falls back to classic for empty string', () {
      expect(TripTheme.forKey('').key, 'classic');
    });
  });

  group('TripTheme.resolve — keyword matching', () {
    test('matches sakura for Japan-related titles', () {
      expect(TripTheme.resolve('Tokyo Adventure').key, 'sakura');
      expect(TripTheme.resolve('Cherry blossom in Kyoto').key, 'sakura');
      expect(TripTheme.resolve('Osaka food tour').key, 'sakura');
    });

    test('matches tropical for tropical destinations', () {
      expect(TripTheme.resolve('Bali surf trip').key, 'tropical');
      expect(TripTheme.resolve('Maldives getaway').key, 'tropical');
      expect(TripTheme.resolve('Hawaii beach vacation').key, 'tropical');
    });

    test('matches alpine for mountain destinations', () {
      expect(TripTheme.resolve('Swiss Alps skiing').key, 'alpine');
      expect(TripTheme.resolve('Zermatt hiking').key, 'alpine');
    });

    test('matches desert for desert destinations', () {
      expect(TripTheme.resolve('Dubai desert safari').key, 'desert');
      expect(TripTheme.resolve('Marrakech road trip').key, 'desert');
    });

    test('matches nordic for Nordic destinations', () {
      expect(TripTheme.resolve('Reykjavik northern lights').key, 'nordic');
      expect(TripTheme.resolve('Oslo fjords').key, 'nordic');
    });

    test('matches mediterranean for Med destinations', () {
      expect(TripTheme.resolve('Santorini holiday').key, 'mediterranean');
      expect(TripTheme.resolve('Amalfi coast drive').key, 'mediterranean');
      expect(TripTheme.resolve('Barcelona city break').key, 'mediterranean');
    });

    test('matches rainforest for jungle destinations', () {
      expect(TripTheme.resolve('Amazon rainforest trek').key, 'rainforest');
      expect(TripTheme.resolve('Costa Rica wildlife').key, 'rainforest');
    });

    test('falls back to classic for unrecognised title', () {
      expect(TripTheme.resolve('My awesome trip').key, 'classic');
      expect(TripTheme.resolve('').key, 'classic');
    });

    test('matching is case-insensitive', () {
      expect(TripTheme.resolve('TOKYO TRIP').key, 'sakura');
      expect(TripTheme.resolve('bali retreat').key, 'tropical');
    });
  });

  group('TripTheme gradients', () {
    test('headerGradient uses gradientStart and gradientEnd', () {
      const theme = TripTheme.classic;
      final grad = theme.headerGradient;
      expect(grad.colors.first, theme.gradientStart);
      expect(grad.colors.last, theme.gradientEnd);
    });

    test('cardBarGradient uses gradientEnd and primary', () {
      const theme = TripTheme.sakura;
      final grad = theme.cardBarGradient;
      expect(grad.colors.first, theme.gradientEnd);
      expect(grad.colors.last, theme.primary);
    });

    test('all 8 presets have distinct primary colours', () {
      final primaries = TripTheme.all.map((t) => t.primary.toARGB32()).toSet();
      expect(primaries.length, TripTheme.all.length);
    });
  });
}
