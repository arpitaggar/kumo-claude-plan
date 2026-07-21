import 'package:flutter/material.dart';

import 'brand.dart';

// ─── Themes ───────────────────────────────────────────────────────────────────
// Two complete themes live here. To add a new one:
//   1. Define palette constants below.
//   2. Build a _ColorScheme and ThemeData getter (copy an existing one).
//   3. Add the enum value in lib/config/theme_provider.dart.
// Font family lives in Brand.fontFamily (lib/config/brand.dart).

class AppTheme {
  AppTheme._();

  // ══════════════════════════════════════════════════════════════════════════
  // Cherry Blossom — original warm-pink / oatmeal palette
  // ══════════════════════════════════════════════════════════════════════════

  static const warmOatmeal    = Color(0xFFF5F2EB);
  static const sakuraStone    = Color(0xFFE5DED3);
  static const cherryBlossom  = Color(0xFFF3C1C6);
  static const softCoral      = Color(0xFFD4667A);
  static const darkEspresso   = Color(0xFF2C1E1C);
  static const earthBrown     = Color(0xFF5D4B46);
  static const cloudWhite     = Color(0xFFFFFFFF);

  static const featuredGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF3C1C6), Color(0xFFE8A0A8), Color(0xFFD4667A)],
  );

  static const _cherryScheme = ColorScheme(
    brightness: Brightness.light,
    primary:              softCoral,
    onPrimary:            cloudWhite,
    primaryContainer:     cherryBlossom,
    onPrimaryContainer:   darkEspresso,
    secondary:            earthBrown,
    onSecondary:          cloudWhite,
    secondaryContainer:   sakuraStone,
    onSecondaryContainer: darkEspresso,
    tertiary:             Color(0xFF6A8F72),
    onTertiary:           cloudWhite,
    tertiaryContainer:    Color(0xFFD1E2D3),
    onTertiaryContainer:  darkEspresso,
    surface:              cloudWhite,
    onSurface:            darkEspresso,
    surfaceContainerHighest: sakuraStone,
    onSurfaceVariant:     earthBrown,
    outline:              Color(0xFFBFB3AE),
    outlineVariant:       sakuraStone,
    error:                Color(0xFFBA1A1A),
    onError:              cloudWhite,
    errorContainer:       Color(0xFFFFDAD6),
    onErrorContainer:     Color(0xFF410002),
    shadow:               Color(0xFF000000),
    scrim:                Color(0xFF000000),
    inverseSurface:       darkEspresso,
    onInverseSurface:     warmOatmeal,
    inversePrimary:       cherryBlossom,
    surfaceTint:          softCoral,
  );

  static ThemeData get light => _buildTheme(
    scheme:     _cherryScheme,
    background: warmOatmeal,
    border:     sakuraStone,
    navIndicator: cherryBlossom.withValues(alpha: 0.4),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Golden Hour — amber / forest-green palette
  // ══════════════════════════════════════════════════════════════════════════

  static const goldenIvory  = Color(0xFFFAF5E4); // scaffold background
  static const warmSand     = Color(0xFFDDD8C0); // borders / subtle surfaces
  static const sunburst     = Color(0xFFF6CB6D); // primary container
  static const amberGold    = Color(0xFFC97A20); // primary interactive
  static const forestGreen  = Color(0xFF1E3D2B); // dark text
  static const oliveGreen   = Color(0xFF5A7B5E); // medium text / icons
  static const deepForest   = Color(0xFF4A7A5A); // tertiary green

  static const goldenHourGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sunburst, Color(0xFFE89A3C), amberGold],
  );

  static const _goldenScheme = ColorScheme(
    brightness: Brightness.light,
    primary:              amberGold,
    onPrimary:            cloudWhite,
    primaryContainer:     sunburst,
    onPrimaryContainer:   forestGreen,
    secondary:            oliveGreen,
    onSecondary:          cloudWhite,
    secondaryContainer:   Color(0xFFC8E0CC),
    onSecondaryContainer: forestGreen,
    tertiary:             deepForest,
    onTertiary:           cloudWhite,
    tertiaryContainer:    Color(0xFFBDD8C4),
    onTertiaryContainer:  forestGreen,
    surface:              cloudWhite,
    onSurface:            forestGreen,
    surfaceContainerHighest: warmSand,
    onSurfaceVariant:     oliveGreen,
    outline:              Color(0xFFA8C4A4),
    outlineVariant:       warmSand,
    error:                Color(0xFFBA1A1A),
    onError:              cloudWhite,
    errorContainer:       Color(0xFFFFDAD6),
    onErrorContainer:     Color(0xFF410002),
    shadow:               Color(0xFF000000),
    scrim:                Color(0xFF000000),
    inverseSurface:       forestGreen,
    onInverseSurface:     goldenIvory,
    inversePrimary:       sunburst,
    surfaceTint:          amberGold,
  );

  static ThemeData get goldenHour => _buildTheme(
    scheme:      _goldenScheme,
    background:  goldenIvory,
    border:      warmSand,
    navIndicator: sunburst.withValues(alpha: 0.4),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Deep Voyage — deep navy / antique gold palette
  // ══════════════════════════════════════════════════════════════════════════

  static const voyageIce   = Color(0xFFEEF2F8); // scaffold background
  static const voyageMist  = Color(0xFFD0DCEF); // borders / subtle surfaces
  static const voyageGold  = Color(0xFFE8B54A); // primary container
  static const voyageAmber = Color(0xFFC88A2A); // primary interactive
  static const voyageNavy  = Color(0xFF0E1B33); // dark text / inverse surface
  static const voyageMid   = Color(0xFF16294D); // medium text / icons
  static const voyageBlue  = Color(0xFF22406E); // secondary / tertiary

  static const deepVoyageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [voyageGold, Color(0xFFD49A34), voyageAmber],
  );

  static const _deepVoyageScheme = ColorScheme(
    brightness: Brightness.light,
    primary:              voyageAmber,
    onPrimary:            cloudWhite,
    primaryContainer:     voyageGold,
    onPrimaryContainer:   voyageNavy,
    secondary:            voyageBlue,
    onSecondary:          cloudWhite,
    secondaryContainer:   Color(0xFFBFD0E8),
    onSecondaryContainer: voyageNavy,
    tertiary:             voyageMid,
    onTertiary:           cloudWhite,
    tertiaryContainer:    Color(0xFFC8D8EE),
    onTertiaryContainer:  voyageNavy,
    surface:              cloudWhite,
    onSurface:            voyageNavy,
    surfaceContainerHighest: voyageMist,
    onSurfaceVariant:     voyageBlue,
    outline:              Color(0xFF8AA0C0),
    outlineVariant:       voyageMist,
    error:                Color(0xFFBA1A1A),
    onError:              cloudWhite,
    errorContainer:       Color(0xFFFFDAD6),
    onErrorContainer:     Color(0xFF410002),
    shadow:               Color(0xFF000000),
    scrim:                Color(0xFF000000),
    inverseSurface:       voyageNavy,
    onInverseSurface:     voyageIce,
    inversePrimary:       voyageGold,
    surfaceTint:          voyageAmber,
  );

  static ThemeData get deepVoyage => _buildTheme(
    scheme:       _deepVoyageScheme,
    background:   voyageIce,
    border:       voyageMist,
    navIndicator: voyageGold.withValues(alpha: 0.4),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Shared builder — keeps component styles DRY across themes
  // ══════════════════════════════════════════════════════════════════════════

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color background,
    required Color border,
    required Color navIndicator,
  }) {
    final primary  = scheme.primary;
    final onSurfaceVariant = scheme.onSurfaceVariant;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: Brand.fontFamily,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cloudWhite,
        elevation: 0,
        shadowColor: Colors.transparent,
        indicatorColor: navIndicator,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary, size: 22);
          }
          return IconThemeData(color: onSurfaceVariant, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: Brand.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }
          return TextStyle(
            fontFamily: Brand.fontFamily,
            fontSize: 11,
            color: onSurfaceVariant,
          );
        }),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: cloudWhite,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: Brand.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: cloudWhite,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: Brand.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: Brand.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cloudWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: onSurfaceVariant, fontFamily: Brand.fontFamily),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: cloudWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      chipTheme: ChipThemeData(
        backgroundColor: border,
        labelStyle: TextStyle(
          fontFamily: Brand.fontFamily,
          fontSize: 12,
          color: scheme.onSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
    );
  }
}
