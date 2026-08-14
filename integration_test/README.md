# Integration tests

Drives the **real** app — real `main()`, real Supabase, real rendering — as
opposed to `flutter test`'s widget tests (`test/`), which run against
mocked providers/usecases and never touch the network. This is Flutter's
official `integration_test` package: on native targets (macOS/iOS/Android)
it gets a real accessibility tree, so tests use `find.text`/`find.byType`
instead of the raw pixel-coordinate taps `scripts/web_smoke_test/` needs
for the web/CanvasKit renderer.

## Running

```bash
flutter test integration_test/app_test.dart -d macos --dart-define-from-file=env.local.json
```

Swap `-d macos` for a simulator/emulator UDID (`xcrun simctl list devices`
for iOS, `flutter emulators --launch <id>` for Android) or a connected
device from `flutter devices`. Needs a real `env.local.json` (see
`env.example.json`) — same file the app's own manual builds use.

**Web is not supported** — `flutter test -d chrome` fails outright
("Web devices are not supported for integration tests yet"), a Flutter
platform limitation as of this SDK version, not something wrong with this
suite. Getting web coverage would mean the older `flutter drive
--driver=test_driver/integration_test.dart` pathway plus a matching
`chromedriver` binary (not installed on this machine) — not worth
duplicating given `scripts/web_smoke_test/` already covers web
deliberately. If that changes upstream, revisit.

## What's covered today

`app_test.dart` — one test, **read-only and unauthenticated**: boots the
real app, lets the real Supabase session check resolve (no session found on
a clean machine), and confirms it lands on the login page. This exercises
the full real startup path (`Supabase.initialize`, secure-storage session
lookup, routing) without creating, modifying, or reading any account data.

**Verified passing on all 3 native targets** (2026-08-14): macOS desktop,
an iOS simulator (iPhone 17 Pro, iOS 26.5), and an Android emulator (Pixel
6, API 33) — each a real, separate app build/install/launch, not just the
same run reused. iOS pulled in CocoaPods for `google_maps_flutter_ios`
only (expected — see the root `CLAUDE.md`/`macos/.gitignore` on why iOS
still needs it after macOS dropped CocoaPods entirely). Android additionally
exercises the `Firebase.initializeApp()` branch of `main()`, which
macOS/iOS (outside `kIosPushReady`) skip.

## Safety rules — read before adding a test that logs in or touches data

This project has already lost a real trip to automated testing once (see
`docs/Checklist.md`'s 2026-08-13 "Incident" entry, and
`scripts/web_smoke_test/README.md`'s safety section it prompted) — this
harness is at least as capable of hitting real infrastructure, so the same
discipline applies here, not just there:

- **Don't add a test that logs into a real personal account** without
  first checking with whoever owns this repo. If authenticated coverage is
  wanted, it needs a **dedicated test account** (credentials passed via
  `--dart-define`, e.g. `TEST_EMAIL`/`TEST_PASSWORD`, never hard-coded in
  the test file or committed) — never the developer's own account.
- **Prefer disposable, clearly-named fixtures** (`SMOKETEST-<timestamp>`
  trips, etc.) over interacting with any pre-existing data, and delete
  them at the end of the test.
- **Treat any delete/revoke/publish action as needing an explicit,
  deliberate assertion of the exact state beforehand** — this suite talks
  to the same live database as everything else in this app; a bug in the
  test is a bug against real data, not a sandboxed environment.
- If a test's result looks wrong or surprising, stop and inspect actual
  state (e.g. the Supabase dashboard) before writing or running more
  tests that build on the assumption it worked.

## Known limitations

- No CI runs these (this project has none — see the root `CLAUDE.md`).
  They're a local, manual verification step, same as
  `scripts/web_smoke_test/`.
- A passing run only proves the target platform/device it ran on. This
  project's own history has cases where a bug's *symptom* was
  platform-specific (e.g. a CanvasKit-web-only crash) even though the root
  cause wasn't — don't treat one green platform as proof for all of them.
