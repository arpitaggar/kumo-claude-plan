import 'package:flutter/material.dart';

/// Defines a destination-based visual theme for a trip.
///
/// Each theme has a primary accent color, gradient pair used in the header
/// and card bar, and a light background tint applied to the scaffold.
class TripTheme {
  const TripTheme({
    required this.key,
    required this.label,
    required this.emoji,
    required this.primary,
    required this.gradientStart,
    required this.gradientEnd,
    required this.backgroundTint,
  });

  final String key;
  final String label;
  final String emoji;
  final Color primary;
  final Color gradientStart;
  final Color gradientEnd;
  final Color backgroundTint;

  /// Gradient for the detail page header background.
  LinearGradient get headerGradient =>
      LinearGradient(colors: [gradientStart, gradientEnd]);

  /// Short horizontal gradient for the card top accent bar.
  LinearGradient get cardBarGradient =>
      LinearGradient(colors: [gradientEnd, primary]);

  // ── Presets ────────────────────────────────────────────────────────────────

  static const classic = TripTheme(
    key: 'classic',
    label: 'Classic',
    emoji: '✈️',
    primary: Color(0xFFD4667A),
    gradientStart: Color(0xFFF5F2EB),
    gradientEnd: Color(0xFFF3C1C6),
    backgroundTint: Color(0xFFF5F2EB),
  );

  static const sakura = TripTheme(
    key: 'sakura',
    label: 'Cherry Blossom',
    emoji: '🌸',
    primary: Color(0xFFB5395A),
    gradientStart: Color(0xFFFDE8EA),
    gradientEnd: Color(0xFFF3C1C6),
    backgroundTint: Color(0xFFFDF5F6),
  );

  static const tropical = TripTheme(
    key: 'tropical',
    label: 'Tropical',
    emoji: '🌴',
    primary: Color(0xFF00897B),
    gradientStart: Color(0xFFE0F7F4),
    gradientEnd: Color(0xFF80CBC4),
    backgroundTint: Color(0xFFF0FDFA),
  );

  static const alpine = TripTheme(
    key: 'alpine',
    label: 'Alpine',
    emoji: '🏔️',
    primary: Color(0xFF1565C0),
    gradientStart: Color(0xFFE3F2FD),
    gradientEnd: Color(0xFF90CAF9),
    backgroundTint: Color(0xFFF0F7FF),
  );

  static const desert = TripTheme(
    key: 'desert',
    label: 'Desert',
    emoji: '🏜️',
    primary: Color(0xFFBF360C),
    gradientStart: Color(0xFFFFF3E0),
    gradientEnd: Color(0xFFFFCC80),
    backgroundTint: Color(0xFFFFFBF5),
  );

  static const nordic = TripTheme(
    key: 'nordic',
    label: 'Nordic',
    emoji: '🌌',
    primary: Color(0xFF5C6BC0),
    gradientStart: Color(0xFFE8EAF6),
    gradientEnd: Color(0xFFC5CAE9),
    backgroundTint: Color(0xFFF3F4FC),
  );

  static const mediterranean = TripTheme(
    key: 'mediterranean',
    label: 'Mediterranean',
    emoji: '🌊',
    primary: Color(0xFF0277BD),
    gradientStart: Color(0xFFFFF9C4),
    gradientEnd: Color(0xFFB3E5FC),
    backgroundTint: Color(0xFFF9FDFF),
  );

  static const rainforest = TripTheme(
    key: 'rainforest',
    label: 'Rainforest',
    emoji: '🌿',
    primary: Color(0xFF2E7D32),
    gradientStart: Color(0xFFF1F8E9),
    gradientEnd: Color(0xFFA5D6A7),
    backgroundTint: Color(0xFFF4FAF4),
  );

  static const all = [
    classic,
    sakura,
    tropical,
    alpine,
    desert,
    nordic,
    mediterranean,
    rainforest,
  ];

  /// Returns the preset matching [key], falling back to [classic].
  static TripTheme forKey(String key) =>
      all.firstWhere((t) => t.key == key, orElse: () => classic);

  /// For 'classic' trips, replaces the hardcoded Cherry-Blossom palette with
  /// the active app theme's primary colors so the card bar, header gradient,
  /// and scaffold tint always complement whichever app theme is selected.
  /// Destination-specific themes (sakura, tropical, …) are returned as-is.
  TripTheme withContext(BuildContext context) {
    if (key != 'classic') {
      return this;
    }
    final cs = Theme.of(context).colorScheme;
    return TripTheme(
      key: key,
      label: label,
      emoji: emoji,
      primary: cs.primary,
      gradientStart: cs.primaryContainer,
      gradientEnd: cs.primary,
      backgroundTint: Theme.of(context).scaffoldBackgroundColor,
    );
  }

  /// Infers a theme from keywords in [title] (case-insensitive).
  /// Returns [classic] when no keyword matches.
  static TripTheme resolve(String title) {
    final t = title.toLowerCase();

    if (_matches(t, [
      'japan', 'tokyo', 'kyoto', 'osaka', 'sakura', 'cherry',
      'okinawa', 'hiroshima', 'nara', 'sapporo', 'hokkaido', 'fukuoka',
    ])) {
      return sakura;
    }

    if (_matches(t, [
      'bali', 'hawaii', 'thailand', 'phuket', 'maldives', 'caribbean',
      'cancun', 'jamaica', 'fiji', 'tropical', 'beach', 'island',
      'indonesia', 'vietnam', 'philippines', 'singapore', 'malaysia',
      'sri lanka', 'bora bora', 'lombok',
    ])) {
      return tropical;
    }

    if (_matches(t, [
      'alps', 'switzerland', 'swiss', 'austria', 'iceland', 'ski',
      'skiing', 'snowboard', 'aspen', 'zermatt', 'chamonix', 'innsbruck',
      'mont blanc', 'winter',
    ])) {
      return alpine;
    }

    if (_matches(t, [
      'morocco', 'dubai', 'egypt', 'sahara', 'jordan', 'oman', 'uae',
      'marrakech', 'abu dhabi', 'riyadh', 'saudi', 'petra', 'desert',
      'cairo', 'luxor',
    ])) {
      return desert;
    }

    if (_matches(t, [
      'norway', 'sweden', 'finland', 'denmark', 'oslo', 'stockholm',
      'copenhagen', 'helsinki', 'aurora', 'northern lights', 'lapland',
      'reykjavik', 'scandinavia',
    ])) {
      return nordic;
    }

    if (_matches(t, [
      'italy', 'greece', 'spain', 'croatia', 'portugal', 'turkey',
      'rome', 'barcelona', 'athens', 'lisbon', 'dubrovnik', 'santorini',
      'mykonos', 'amalfi', 'sicily', 'malta', 'mediterranean',
      'positano', 'venice', 'florence',
    ])) {
      return mediterranean;
    }

    if (_matches(t, [
      'costa rica', 'amazon', 'new zealand', 'rainforest', 'jungle',
      'ecuador', 'colombia', 'peru', 'patagonia', 'brazil', 'kenya',
      'safari', 'africa', 'tanzania', 'rwanda',
    ])) {
      return rainforest;
    }

    return classic;
  }

  static bool _matches(String text, List<String> keywords) =>
      keywords.any(text.contains);
}
