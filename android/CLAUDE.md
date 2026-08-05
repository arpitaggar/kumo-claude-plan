# android/

Migrated from the project root CLAUDE.md (2026-08-03 doctor cleanup) — loads only when working under android/.

### Android Splash Screen Architecture

Two layers cover different API levels:

#### Pre-Android 12 (API < 31)

- `styles.xml` `LaunchTheme.windowBackground` → `@drawable/launch_background`
- `drawable/launch_background.xml` and `drawable-v21/launch_background.xml` → single `<bitmap gravity="fill" src="@drawable/background"/>`
- `background.png` is a **manually generated** portrait image (1080 × 2400 px) with the same radial gradient as the app icon (`centre #16294D → edges #0E1B33`), extended to full portrait dimensions so there is no visible seam around the icon.
- **Do not regenerate with `flutter_native_splash:create`** — it would overwrite `background.png` with a flat colour.

#### Android 12+ (API 31+)

- OS splash is controlled by `windowSplashScreenAnimatedIcon` in `values-v31/styles.xml`
- Points to `@drawable/android12splash` — **transparent RGBA PNGs** (logo strokes only, no background)
- `windowSplashScreenIconBackgroundColor` = `#0E1B33` fills the icon circle; same colour used for outer background, so no visible ring
- Files: `drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/android12splash.png` (and `-night-` variants)
- `colors.xml` `splash_background` = `#0E1B33` (used by `NormalTheme` during Flutter engine init)

**Key constraint:** Android 12 OS splash is always the same regardless of the user's selected in-app theme; it cannot be changed at runtime.

