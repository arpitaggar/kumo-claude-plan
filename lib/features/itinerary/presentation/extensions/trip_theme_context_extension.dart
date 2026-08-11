import 'package:flutter/material.dart';

import '../../domain/entities/trip_theme.dart';

/// Presentation-layer companion to [TripTheme] — kept out of the domain
/// entity itself (which must stay framework-independent) since this needs
/// [BuildContext]/[Theme.of] to read the active app theme.
extension TripThemeContextX on TripTheme {
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
}
