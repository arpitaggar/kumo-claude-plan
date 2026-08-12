import 'package:flutter/material.dart';

import 'brand.dart';
import 'theme_provider.dart';

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

  static const warmOatmeal = Color(0xFFF5F2EB);
  static const sakuraStone = Color(0xFFE5DED3);
  static const cherryBlossom = Color(0xFFF3C1C6);
  static const softCoral = Color(0xFFD4667A);
  static const darkEspresso = Color(0xFF2C1E1C);
  static const earthBrown = Color(0xFF5D4B46);
  static const cloudWhite = Color(0xFFFFFFFF);

  static const featuredGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF3C1C6), Color(0xFFE8A0A8), Color(0xFFD4667A)],
  );

  static const _cherryScheme = ColorScheme(
    brightness: Brightness.light,
    primary: softCoral,
    onPrimary: cloudWhite,
    primaryContainer: cherryBlossom,
    onPrimaryContainer: darkEspresso,
    secondary: earthBrown,
    onSecondary: cloudWhite,
    secondaryContainer: sakuraStone,
    onSecondaryContainer: darkEspresso,
    tertiary: Color(0xFF6A8F72),
    onTertiary: cloudWhite,
    tertiaryContainer: Color(0xFFD1E2D3),
    onTertiaryContainer: darkEspresso,
    surface: cloudWhite,
    onSurface: darkEspresso,
    surfaceContainerHighest: sakuraStone,
    onSurfaceVariant: earthBrown,
    outline: Color(0xFFBFB3AE),
    outlineVariant: sakuraStone,
    error: Color(0xFFBA1A1A),
    onError: cloudWhite,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: darkEspresso,
    onInverseSurface: warmOatmeal,
    inversePrimary: cherryBlossom,
    surfaceTint: softCoral,
  );

  static ThemeData get light => _buildTheme(
    scheme: _cherryScheme,
    background: warmOatmeal,
    border: sakuraStone,
    navIndicator: cherryBlossom.withValues(alpha: 0.4),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Golden Hour — amber / forest-green palette
  // ══════════════════════════════════════════════════════════════════════════

  static const goldenIvory = Color(0xFFFAF5E4); // scaffold background
  static const warmSand = Color(0xFFDDD8C0); // borders / subtle surfaces
  static const sunburst = Color(0xFFF6CB6D); // primary container
  static const amberGold = Color(0xFFC97A20); // primary interactive
  static const forestGreen = Color(0xFF1E3D2B); // dark text
  static const oliveGreen = Color(0xFF5A7B5E); // medium text / icons
  static const deepForest = Color(0xFF4A7A5A); // tertiary green

  static const goldenHourGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sunburst, Color(0xFFE89A3C), amberGold],
  );

  static const _goldenScheme = ColorScheme(
    brightness: Brightness.light,
    primary: amberGold,
    onPrimary: cloudWhite,
    primaryContainer: sunburst,
    onPrimaryContainer: forestGreen,
    secondary: oliveGreen,
    onSecondary: cloudWhite,
    secondaryContainer: Color(0xFFC8E0CC),
    onSecondaryContainer: forestGreen,
    tertiary: deepForest,
    onTertiary: cloudWhite,
    tertiaryContainer: Color(0xFFBDD8C4),
    onTertiaryContainer: forestGreen,
    surface: cloudWhite,
    onSurface: forestGreen,
    surfaceContainerHighest: warmSand,
    onSurfaceVariant: oliveGreen,
    outline: Color(0xFFA8C4A4),
    outlineVariant: warmSand,
    error: Color(0xFFBA1A1A),
    onError: cloudWhite,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: forestGreen,
    onInverseSurface: goldenIvory,
    inversePrimary: sunburst,
    surfaceTint: amberGold,
  );

  static ThemeData get goldenHour => _buildTheme(
    scheme: _goldenScheme,
    background: goldenIvory,
    border: warmSand,
    navIndicator: sunburst.withValues(alpha: 0.4),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Deep Voyage — deep navy / antique gold palette
  // ══════════════════════════════════════════════════════════════════════════

  static const voyageIce = Color(0xFFEEF2F8); // scaffold background
  static const voyageMist = Color(0xFFD0DCEF); // borders / subtle surfaces
  static const voyageGold = Color(0xFFE8B54A); // primary container
  static const voyageAmber = Color(0xFFC88A2A); // primary interactive
  static const voyageNavy = Color(0xFF0E1B33); // dark text / inverse surface
  static const voyageMid = Color(0xFF16294D); // medium text / icons
  static const voyageBlue = Color(0xFF22406E); // secondary / tertiary

  static const deepVoyageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [voyageGold, Color(0xFFD49A34), voyageAmber],
  );

  static const _deepVoyageScheme = ColorScheme(
    brightness: Brightness.light,
    primary: voyageAmber,
    onPrimary: cloudWhite,
    primaryContainer: voyageGold,
    onPrimaryContainer: voyageNavy,
    secondary: voyageBlue,
    onSecondary: cloudWhite,
    secondaryContainer: Color(0xFFBFD0E8),
    onSecondaryContainer: voyageNavy,
    tertiary: voyageMid,
    onTertiary: cloudWhite,
    tertiaryContainer: Color(0xFFC8D8EE),
    onTertiaryContainer: voyageNavy,
    surface: cloudWhite,
    onSurface: voyageNavy,
    surfaceContainerHighest: voyageMist,
    onSurfaceVariant: voyageBlue,
    outline: Color(0xFF8AA0C0),
    outlineVariant: voyageMist,
    error: Color(0xFFBA1A1A),
    onError: cloudWhite,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: voyageNavy,
    onInverseSurface: voyageIce,
    inversePrimary: voyageGold,
    surfaceTint: voyageAmber,
  );

  static ThemeData get deepVoyage => _buildTheme(
    scheme: _deepVoyageScheme,
    background: voyageIce,
    border: voyageMist,
    navIndicator: voyageGold.withValues(alpha: 0.4),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Synthwave Tokyo — the app's first dark theme: magenta-purple dusk sky
  // with an orange/gold sunset sun, matching the reference Tokyo skyline art.
  // ══════════════════════════════════════════════════════════════════════════

  static const synthwaveBg = Color(
    0xFF2A0F52,
  ); // scaffold background — deep dusk violet
  static const synthwaveSurface = Color(
    0xFF3D1B6E,
  ); // cards / nav / inputs — mid-sky purple
  static const synthwaveOutline = Color(0xFF4A2680); // dividers / borders
  static const synthwaveOrange = Color(
    0xFFFF9152,
  ); // primary — sunset-orange sun
  static const synthwaveMagenta = Color(
    0xFFE14FA0,
  ); // secondary — vivid sky magenta
  static const synthwaveGold = Color(0xFFFFD166); // tertiary — sun core gold
  static const synthwaveOnSurface = Color(
    0xFFF5E9FF,
  ); // near-white lavender text
  static const _synthwaveInk = Color(
    0xFF2A1140,
  ); // dark ink for text on bright accents

  static const _synthwaveScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: synthwaveOrange,
    onPrimary: _synthwaveInk,
    primaryContainer: Color(0xFFFFC896),
    onPrimaryContainer: Color(0xFF5C2A00),
    secondary: synthwaveMagenta,
    onSecondary: cloudWhite,
    secondaryContainer: Color(0xFFFFD3EC),
    onSecondaryContainer: Color(0xFF5C0A3C),
    tertiary: synthwaveGold,
    onTertiary: _synthwaveInk,
    tertiaryContainer: Color(0xFFFFF0C2),
    onTertiaryContainer: Color(0xFF4D3800),
    surface: synthwaveSurface,
    onSurface: synthwaveOnSurface,
    surfaceContainerHighest: synthwaveOutline,
    onSurfaceVariant: Color(0xFFC9A8DE),
    outline: Color(0xFF8A5CB0),
    outlineVariant: synthwaveOutline,
    // Material's standard *dark*-theme error pair — a light-theme error
    // container would clash badly against this near-black scaffold.
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: synthwaveOnSurface,
    onInverseSurface: synthwaveSurface,
    inversePrimary: Color(0xFFC2410C),
    surfaceTint: synthwaveOrange,
  );

  static ThemeData get synthwaveTokyo => _buildTheme(
    scheme: _synthwaveScheme,
    background: synthwaveBg,
    border: synthwaveOutline,
    navIndicator: synthwaveOrange.withValues(alpha: 0.35),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // White & Charcoal — minimal monochrome light palette
  // ══════════════════════════════════════════════════════════════════════════

  static const whiteBg = Color(0xFFFAFAFA); // scaffold background
  static const charcoal = Color(0xFF2B2B2E); // primary
  static const charcoalGray = Color(0xFF6E6E73); // secondary / medium text
  static const charcoalDark = Color(0xFF1C1C1E); // dark text

  static const _whiteCharcoalScheme = ColorScheme(
    brightness: Brightness.light,
    primary: charcoal,
    onPrimary: cloudWhite,
    primaryContainer: Color(0xFFDCDCDE),
    onPrimaryContainer: charcoalDark,
    secondary: charcoalGray,
    onSecondary: cloudWhite,
    secondaryContainer: Color(0xFFE4E4E7),
    onSecondaryContainer: Color(0xFF3A3A3D),
    tertiary: Color(0xFF8A7F72),
    onTertiary: cloudWhite,
    tertiaryContainer: Color(0xFFE9E4DE),
    onTertiaryContainer: Color(0xFF332D26),
    surface: cloudWhite,
    onSurface: charcoalDark,
    surfaceContainerHighest: Color(0xFFEDEDEF),
    onSurfaceVariant: charcoalGray,
    outline: Color(0xFFB8B8BC),
    outlineVariant: Color(0xFFE5E5EA),
    error: Color(0xFFBA1A1A),
    onError: cloudWhite,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: charcoal,
    onInverseSurface: Color(0xFFF5F5F5),
    inversePrimary: Color(0xFFC7C7CC),
    surfaceTint: charcoal,
  );

  static ThemeData get whiteAndCharcoal => _buildTheme(
    scheme: _whiteCharcoalScheme,
    background: whiteBg,
    border: const Color(0xFFE5E5EA),
    navIndicator: charcoal.withValues(alpha: 0.12),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Warm Oat & Light Blue — soft warm neutral background, sky-blue accent
  // ══════════════════════════════════════════════════════════════════════════

  static const oatBg = Color(0xFFF6EFE2); // scaffold background
  static const oatSurface = Color(0xFFFFFCF5); // cards / inputs
  static const oatBorder = Color(0xFFEDE4D2); // dividers / subtle surfaces
  static const skyBlue = Color(0xFF3D84C6); // primary
  static const oatTaupe = Color(0xFF8A7A63); // secondary
  static const oatSage = Color(0xFF6E9A7B); // tertiary
  static const oatOnSurface = Color(0xFF3A3226); // warm dark brown text

  static const _oatSkyScheme = ColorScheme(
    brightness: Brightness.light,
    primary: skyBlue,
    onPrimary: cloudWhite,
    primaryContainer: Color(0xFFBFE0F7),
    onPrimaryContainer: Color(0xFF0B3A5C),
    secondary: oatTaupe,
    onSecondary: cloudWhite,
    secondaryContainer: Color(0xFFEDE1CE),
    onSecondaryContainer: Color(0xFF3A3020),
    tertiary: oatSage,
    onTertiary: cloudWhite,
    tertiaryContainer: Color(0xFFD3E6D8),
    onTertiaryContainer: Color(0xFF1F3A28),
    surface: oatSurface,
    onSurface: oatOnSurface,
    surfaceContainerHighest: oatBorder,
    onSurfaceVariant: Color(0xFF7A6F5B),
    outline: Color(0xFFC2B49A),
    outlineVariant: oatBorder,
    error: Color(0xFFBA1A1A),
    onError: cloudWhite,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: oatOnSurface,
    onInverseSurface: oatBg,
    inversePrimary: Color(0xFF9BCBEF),
    surfaceTint: skyBlue,
  );

  static ThemeData get warmOatLightBlue => _buildTheme(
    scheme: _oatSkyScheme,
    background: oatBg,
    border: oatBorder,
    navIndicator: skyBlue.withValues(alpha: 0.35),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Sunset Coral — warm terracotta-red / peach-orange palette
  // ══════════════════════════════════════════════════════════════════════════

  static const sunsetIvory = Color(0xFFFBF1EB); // scaffold background
  static const sunsetBlush = Color(0xFFF4DDD0); // borders / subtle surfaces
  static const sunsetRed = Color(0xFFC1442C); // primary interactive
  static const sunsetPeach = Color(0xFFF4A97E); // primary container
  static const sunsetAmber = Color(0xFFE8973F); // secondary
  static const sunsetTeal = Color(0xFF5B8A82); // tertiary — cool complement
  static const sunsetDeep = Color(0xFF3A1F16); // dark text

  static const sunsetCoralGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sunsetPeach, Color(0xFFE06B4C), sunsetRed],
  );

  static const _sunsetCoralScheme = ColorScheme(
    brightness: Brightness.light,
    primary: sunsetRed,
    onPrimary: cloudWhite,
    primaryContainer: sunsetPeach,
    onPrimaryContainer: sunsetDeep,
    secondary: sunsetAmber,
    onSecondary: cloudWhite,
    secondaryContainer: Color(0xFFFBE0BE),
    onSecondaryContainer: sunsetDeep,
    tertiary: sunsetTeal,
    onTertiary: cloudWhite,
    tertiaryContainer: Color(0xFFD3E6E2),
    onTertiaryContainer: Color(0xFF15332E),
    surface: cloudWhite,
    onSurface: sunsetDeep,
    surfaceContainerHighest: sunsetBlush,
    onSurfaceVariant: Color(0xFF8A5C4A),
    outline: Color(0xFFD9AE9A),
    outlineVariant: sunsetBlush,
    error: Color(0xFFBA1A1A),
    onError: cloudWhite,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: sunsetDeep,
    onInverseSurface: sunsetIvory,
    inversePrimary: sunsetPeach,
    surfaceTint: sunsetRed,
  );

  static ThemeData get sunsetCoral => _buildTheme(
    scheme: _sunsetCoralScheme,
    background: sunsetIvory,
    border: sunsetBlush,
    navIndicator: sunsetPeach.withValues(alpha: 0.4),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Dawn Flight — pre-dawn navy sky with a warm sunrise accent (dark theme)
  // ══════════════════════════════════════════════════════════════════════════

  static const dawnBg = Color(
    0xFF1B2A4A,
  ); // scaffold background — deep pre-dawn navy
  static const dawnSurface = Color(0xFF243A5E); // cards / nav / inputs
  static const dawnOutline = Color(0xFF2E4A73); // dividers / borders
  static const dawnOrange = Color(0xFFF2A65A); // primary — sunrise orange
  static const dawnBlue = Color(0xFF6FA0D8); // secondary — brightened sky blue
  static const dawnGold = Color(0xFFFFD37A); // tertiary — sunrise gold
  static const dawnOnSurface = Color(0xFFEAF0FA); // pale ice-blue text
  static const _dawnInk = Color(
    0xFF1B2A4A,
  ); // dark ink for text on bright accents

  static const dawnFlightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [dawnGold, dawnOrange, Color(0xFFB5651D)],
  );

  static const _dawnFlightScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: dawnOrange,
    onPrimary: _dawnInk,
    primaryContainer: Color(0xFFFFD9AE),
    onPrimaryContainer: Color(0xFF5C2E00),
    secondary: dawnBlue,
    onSecondary: _dawnInk,
    secondaryContainer: Color(0xFFCFE2F5),
    onSecondaryContainer: Color(0xFF0A2A4A),
    tertiary: dawnGold,
    onTertiary: _dawnInk,
    tertiaryContainer: Color(0xFFFFF0C8),
    onTertiaryContainer: Color(0xFF4D3800),
    surface: dawnSurface,
    onSurface: dawnOnSurface,
    surfaceContainerHighest: dawnOutline,
    onSurfaceVariant: Color(0xFFAFC4E0),
    outline: Color(0xFF5C82AE),
    outlineVariant: dawnOutline,
    // Material's standard *dark*-theme error pair — matches Synthwave Tokyo.
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: dawnOnSurface,
    onInverseSurface: dawnSurface,
    inversePrimary: Color(0xFFB5651D),
    surfaceTint: dawnOrange,
  );

  static ThemeData get dawnFlight => _buildTheme(
    scheme: _dawnFlightScheme,
    background: dawnBg,
    border: dawnOutline,
    navIndicator: dawnOrange.withValues(alpha: 0.35),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Verdigris Bronze — teal-green patina with warm bronze/rust accents
  // ══════════════════════════════════════════════════════════════════════════

  static const verdigrisBg = Color(0xFFF0F2EC); // scaffold background
  static const verdigrisBorder = Color(
    0xFFDDE3D8,
  ); // dividers / subtle surfaces
  static const verdigrisTeal = Color(0xFF3F7A6E); // primary
  static const verdigrisCopper = Color(0xFF8A6A3A); // secondary
  static const verdigrisRust = Color(0xFFB5651D); // tertiary
  static const verdigrisDark = Color(0xFF1E2E28); // dark text

  static const verdigrisBronzeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC9863F), verdigrisCopper, verdigrisTeal],
  );

  static const _verdigrisBronzeScheme = ColorScheme(
    brightness: Brightness.light,
    primary: verdigrisTeal,
    onPrimary: cloudWhite,
    primaryContainer: Color(0xFFBEDCD3),
    onPrimaryContainer: Color(0xFF0C2A22),
    secondary: verdigrisCopper,
    onSecondary: cloudWhite,
    secondaryContainer: Color(0xFFEBDCC0),
    onSecondaryContainer: Color(0xFF332608),
    tertiary: verdigrisRust,
    onTertiary: cloudWhite,
    tertiaryContainer: Color(0xFFF6D9BC),
    onTertiaryContainer: Color(0xFF3D2000),
    surface: cloudWhite,
    onSurface: verdigrisDark,
    surfaceContainerHighest: verdigrisBorder,
    onSurfaceVariant: Color(0xFF5C6E64),
    outline: Color(0xFFA8BCB2),
    outlineVariant: verdigrisBorder,
    error: Color(0xFFBA1A1A),
    onError: cloudWhite,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: verdigrisDark,
    onInverseSurface: verdigrisBg,
    inversePrimary: Color(0xFFBEDCD3),
    surfaceTint: verdigrisTeal,
  );

  static ThemeData get verdigrisBronze => _buildTheme(
    scheme: _verdigrisBronzeScheme,
    background: verdigrisBg,
    border: verdigrisBorder,
    navIndicator: verdigrisTeal.withValues(alpha: 0.3),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Cloud Silver — cool teal + slate-blue palette on a pale sky background
  // ══════════════════════════════════════════════════════════════════════════

  static const cloudBg = Color(0xFFF3F6FA); // scaffold background
  static const cloudBorder = Color(0xFFDCE4EF); // dividers / subtle surfaces
  static const cloudTeal = Color(0xFF1E9A85); // primary
  static const cloudSlate = Color(0xFF5B6B8C); // secondary
  static const cloudSky = Color(0xFF6E8FBA); // tertiary
  static const cloudDark = Color(0xFF1E2733); // dark text

  static const cloudSilverGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC9D6E8), cloudSky, cloudTeal],
  );

  static const _cloudSilverScheme = ColorScheme(
    brightness: Brightness.light,
    primary: cloudTeal,
    onPrimary: cloudWhite,
    primaryContainer: Color(0xFFBEE8DE),
    onPrimaryContainer: Color(0xFF00332A),
    secondary: cloudSlate,
    onSecondary: cloudWhite,
    secondaryContainer: Color(0xFFDDE2ED),
    onSecondaryContainer: cloudDark,
    tertiary: cloudSky,
    onTertiary: cloudWhite,
    tertiaryContainer: Color(0xFFD3E0F0),
    onTertiaryContainer: Color(0xFF14263C),
    surface: cloudWhite,
    onSurface: cloudDark,
    surfaceContainerHighest: cloudBorder,
    onSurfaceVariant: Color(0xFF5B6B7C),
    outline: Color(0xFFAEBBD0),
    outlineVariant: cloudBorder,
    error: Color(0xFFBA1A1A),
    onError: cloudWhite,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: cloudDark,
    onInverseSurface: cloudBg,
    inversePrimary: Color(0xFFBEE8DE),
    surfaceTint: cloudTeal,
  );

  static ThemeData get cloudSilver => _buildTheme(
    scheme: _cloudSilverScheme,
    background: cloudBg,
    border: cloudBorder,
    navIndicator: cloudTeal.withValues(alpha: 0.3),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Onyx & Gold — enforced Work Mode theme (dark). Never user-selectable via
  // the theme picker; applied automatically whenever Work Mode is active.
  // ══════════════════════════════════════════════════════════════════════════

  static const onyxBg = Color(0xFF121212); // scaffold background
  static const onyxSurface = Color(0xFF1C1A17); // cards / nav / inputs
  static const onyxOutline = Color(0xFF3A342A); // dividers / borders
  static const onyxGoldColor = Color(0xFFD4AF37); // primary — metallic gold
  static const onyxBronze = Color(0xFFAD8A56); // secondary
  static const onyxCopper = Color(0xFFB87333); // tertiary
  static const onyxOnSurface = Color(0xFFF2E9D8); // warm ivory text
  static const _onyxInk = Color(0xFF1C1508); // dark ink on bright gold/bronze

  static const _onyxGoldScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: onyxGoldColor,
    onPrimary: _onyxInk,
    primaryContainer: Color(0xFF4A3C10),
    onPrimaryContainer: Color(0xFFFFE9A8),
    secondary: onyxBronze,
    onSecondary: _onyxInk,
    secondaryContainer: Color(0xFF3A2E18),
    onSecondaryContainer: Color(0xFFE8D4AC),
    tertiary: onyxCopper,
    onTertiary: cloudWhite,
    tertiaryContainer: Color(0xFF3E2410),
    onTertiaryContainer: Color(0xFFFFD9B8),
    surface: onyxSurface,
    onSurface: onyxOnSurface,
    surfaceContainerHighest: onyxOutline,
    onSurfaceVariant: Color(0xFFC9BBA0),
    outline: Color(0xFF6E6248),
    outlineVariant: onyxOutline,
    // Material's standard *dark*-theme error pair — matches Synthwave Tokyo /
    // Dawn Flight.
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: onyxOnSurface,
    onInverseSurface: onyxSurface,
    inversePrimary: Color(0xFF8A6D1E),
    surfaceTint: onyxGoldColor,
  );

  static ThemeData get onyxGoldTheme => _buildTheme(
    scheme: _onyxGoldScheme,
    background: onyxBg,
    border: onyxOutline,
    navIndicator: onyxGoldColor.withValues(alpha: 0.3),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Lookup table — the single KumoTheme → ThemeData mapping. `MaterialApp`
  // (main.dart) reads this instead of re-declaring its own switch over every
  // enum value, which previously had to stay in lockstep with the getters
  // above by hand.
  // ══════════════════════════════════════════════════════════════════════════

  static final Map<KumoTheme, ThemeData> all = {
    KumoTheme.cherryBlossom: light,
    KumoTheme.goldenHour: goldenHour,
    KumoTheme.deepVoyage: deepVoyage,
    KumoTheme.synthwaveTokyo: synthwaveTokyo,
    KumoTheme.whiteAndCharcoal: whiteAndCharcoal,
    KumoTheme.warmOatLightBlue: warmOatLightBlue,
    KumoTheme.sunsetCoral: sunsetCoral,
    KumoTheme.dawnFlight: dawnFlight,
    KumoTheme.verdigrisBronze: verdigrisBronze,
    KumoTheme.cloudSilver: cloudSilver,
    KumoTheme.onyxGold: onyxGoldTheme,
  };

  // ══════════════════════════════════════════════════════════════════════════
  // Shared builder — keeps component styles DRY across themes
  // ══════════════════════════════════════════════════════════════════════════

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color background,
    required Color border,
    required Color navIndicator,
  }) {
    final primary = scheme.primary;
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
        backgroundColor: scheme.surface,
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
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
        fillColor: scheme.surface,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(
          color: onSurfaceVariant,
          fontFamily: Brand.fontFamily,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
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
