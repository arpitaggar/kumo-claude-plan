import 'package:flutter/material.dart';

/// Kumo design system — Personal Mode (cherry blossom / warm oatmeal).
class AppTheme {
  AppTheme._();

  // ── Brand palette ──────────────────────────────────────────────────────────
  static const warmOatmeal    = Color(0xFFF5F2EB);
  static const sakuraStone    = Color(0xFFE5DED3);
  static const cherryBlossom  = Color(0xFFF3C1C6);
  static const softCoral      = Color(0xFFD4667A);  // primary interactive
  static const darkEspresso   = Color(0xFF2C1E1C);
  static const earthBrown     = Color(0xFF5D4B46);
  static const cloudWhite     = Color(0xFFFFFFFF);

  // Gradient used on featured trip cards
  static const featuredGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF3C1C6), Color(0xFFE8A0A8), Color(0xFFD4667A)],
  );

  static const _scheme = ColorScheme(
    brightness: Brightness.light,
    // primary
    primary:            softCoral,
    onPrimary:          cloudWhite,
    primaryContainer:   cherryBlossom,
    onPrimaryContainer: darkEspresso,
    // secondary
    secondary:          earthBrown,
    onSecondary:        cloudWhite,
    secondaryContainer: sakuraStone,
    onSecondaryContainer: darkEspresso,
    // tertiary – soft moss from the palette
    tertiary:           Color(0xFF6A8F72),
    onTertiary:         cloudWhite,
    tertiaryContainer:  Color(0xFFD1E2D3),
    onTertiaryContainer: darkEspresso,
    // surface / background
    surface:            cloudWhite,
    onSurface:          darkEspresso,
    surfaceContainerHighest: sakuraStone,
    onSurfaceVariant:   earthBrown,
    // outline
    outline:            Color(0xFFBFB3AE),
    outlineVariant:     sakuraStone,
    // error
    error:              Color(0xFFBA1A1A),
    onError:            cloudWhite,
    errorContainer:     Color(0xFFFFDAD6),
    onErrorContainer:   Color(0xFF410002),
    // misc
    shadow:             Color(0xFF000000),
    scrim:              Color(0xFF000000),
    inverseSurface:     darkEspresso,
    onInverseSurface:   warmOatmeal,
    inversePrimary:     cherryBlossom,
    surfaceTint:        softCoral,
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: _scheme,
    scaffoldBackgroundColor: warmOatmeal,
    fontFamily: 'Poppins',

    // ── AppBar ──────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: warmOatmeal,
      foregroundColor: darkEspresso,
    ),

    // ── NavigationBar (bottom nav) ──────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cloudWhite,
      elevation: 0,
      shadowColor: Colors.transparent,
      indicatorColor: cherryBlossom.withValues(alpha: 0.4),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: softCoral, size: 22);
        }
        return const IconThemeData(color: earthBrown, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: softCoral,
          );
        }
        return const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          color: earthBrown,
        );
      }),
    ),

    // ── Buttons ─────────────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: softCoral,
        foregroundColor: cloudWhite,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: softCoral,
        foregroundColor: cloudWhite,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: softCoral,
        side: const BorderSide(color: softCoral),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: softCoral),
    ),

    // ── Inputs ──────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cloudWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: sakuraStone),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: sakuraStone),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: softCoral, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: earthBrown, fontFamily: 'Poppins'),
    ),

    // ── Cards ───────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      color: cloudWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),

    // ── Divider ─────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: sakuraStone,
      thickness: 1,
      space: 1,
    ),

    // ── Chips ───────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: sakuraStone,
      labelStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        color: darkEspresso,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    ),
  );
}
