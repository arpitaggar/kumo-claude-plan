// ─── Brand Configuration ────────────���────────────────────��───────────────────
//
// One-stop shop for all visual identity. To swap the look-and-feel:
//
//  • App name / tagline / font  — change the constants below.
//  • Per-theme in-app logo      — update the path constants in the Logos section.
//  • App-icon / splash PNGs     — replace assets/icons/app_icon.png and
//                                 adaptive_icon_foreground_deep_voyage.png, then
//                                 run: python3 scripts/gen_icons.py
//                                 background.png (portrait launch image) is
//                                 manually managed — regenerate via gen_icons.py
//                                 or scripts/gen_background.py if the gradient
//                                 or icon changes. Do NOT run flutter_native_splash.
//  • Color palette              — see lib/config/theme.dart.

import 'theme_provider.dart';

class Brand {
  Brand._();

  // ── Identity ─────────────────────────────��──────────────────────��───────────
  static const String appName    = 'Kumo';
  static const String tagline    = 'Plan. Go. Explore.';
  static const String fontFamily = 'Poppins';

  // ── Logos (SVG) ────────────────────────────────────────��────────────────────
  // Each theme has its own logo. Add a new case here when adding a new theme.
  static const String _goldenHourLogo    = 'assets/icons/kumo_logo_golden_hour.svg';
  static const String _cherryBlossomLogo = 'assets/icons/kumo_logo_charcoal_depth_soft_faint_edge.svg';
  static const String _deepVoyageLogo    = 'assets/icons/kumo_logo_deep_voyage.svg';

  static String logoFor(KumoTheme theme) => switch (theme) {
    KumoTheme.goldenHour    => _goldenHourLogo,
    KumoTheme.cherryBlossom => _cherryBlossomLogo,
    KumoTheme.deepVoyage    => _deepVoyageLogo,
  };
}
