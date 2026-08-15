# Web smoke test harness

Drives Kumo's Flutter **web** build with headless Chrome + Playwright, so it
can be visually verified and interacted with from a dev environment that has
no attached display and no iOS/Android simulator — the situation this repo's
own dev environment is in as of 2026-08. `flutter test` alone can't catch
layout/rendering bugs (it uses a fake renderer) or bugs specific to the
CanvasKit web renderer; this harness runs the real thing against a real,
live Supabase project.

This exists because a 2026-08-13 session used exactly this approach ad hoc
from a scratch directory and found four real, previously-unknown bugs in
under two hours (two rendering crashes, one Work-Mode-breaking-for-every-org
query bug, one Hitchhiker/chat integration crash) — see `docs/Checklist.md`'s
"Real device/simulator smoke test" entries for the full writeup. This
directory captures that approach as a reusable, safer tool instead of
starting from scratch next time.

## Setup

```bash
cd scripts/web_smoke_test
npm install
```

Needs a local Chrome or Chromium install (checked at `driver.js`'s
`CHROME_CANDIDATES` — edit if yours is somewhere else). Does **not** download
Playwright's bundled browsers (`playwright-core`, not `playwright`) — it
drives your existing Chrome directly.

## Running

1. Start the app's web build in one terminal, from the repo root:
   ```bash
   flutter run -d web-server --web-port=8765 --dart-define-from-file=env.local.json
   ```
   (needs a real `env.local.json` — see the repo root README/`CLAUDE.md`.)
2. In another terminal, from this directory:
   ```bash
   node example_login_and_home.js   # or your own script
   ```
3. First run: edit the script to pass real login credentials once. `driver.js`
   saves the session to `auth.json` (gitignored) after a successful login, so
   every script after that reuses it automatically — no need to re-login per
   script.

Screenshots go to `scripts/web_smoke_test/screenshots/` (gitignored) via
`driver.screenshot(page, 'name.png')`.

## Writing a new script

Copy `example_login_and_home.js`. Use `driver.js`'s exports — `launch`,
`tap`, `tapDestructive`, `typeText`, `login`, `workModeState`,
`ensureWorkMode`, `goHome`, `screenshot`. Read the doc comment on each
before using it; several exist specifically because the obvious approach
was flaky in practice (see the comments on `tap` and `ensureWorkMode`).

**Prefer `integration_test/authenticated_flows_test.dart` over adding a new
destructive action here at all.** It runs against a real accessibility
tree (`find.text(...)`), so it can actually confirm which screen is
showing before acting — this harness fundamentally can't (see "Known
limitations" below). Reach for this directory only for what it's actually
for: visual/rendering verification and reproducing CanvasKit-web-specific
bugs.

**Coordinates are per-screen and not reusable across screens.** Take a
screenshot, read pixel positions off of *that* image, and hard-code them for
*that* screen only. A coordinate that's a button on one screen can be empty
space — or something else entirely — on another. This was the proximate
cause of every flaky result in the 2026-08-13 session.

## Safety rules — read before writing a script that changes data

On 2026-08-13, a script assumed Work Mode was in a particular state instead
of checking it, ended up looking at the wrong screen, and a coordinate that
was safe on the *intended* screen (delete a disposable test trip) deleted a
real trip on the *actual* one — no confirmation dialog existed at the time
to catch it (that gap is now fixed, see `ItineraryCard`, but don't rely on
every destructive action in this app having a confirming dialog you can
count on).

- **Never call a delete/remove/revoke action against a coordinate you
  haven't just re-verified with a screenshot from *this exact run*.** Don't
  reuse a coordinate captured in an earlier script or an earlier session.
  Use `tapDestructive` (not bare `tap`) for these — it screenshots
  immediately before tapping and logs where, so this rule is mechanical
  rather than something to remember. Still inspect the screenshot yourself;
  the helper creates the evidence, it doesn't check it for you.
- **A tap immediately after a screen-transition tap (e.g. switching tabs,
  then acting on what should now be showing) carries the same risk even
  if nothing about it looks destructive in isolation** — this is exactly
  the 2026-08-13 KumoTest sequence: tap a tab, assume the transition
  landed, tap again. Use `tapDestructive` for the second tap in that
  pattern too, not just for taps that are obviously delete buttons.
- **Prefer creating your own disposable fixtures** (a trip titled e.g.
  `SMOKETEST-<timestamp>`, a Hitchhiker named `smoketest-probe`) over
  interacting with the account's real data, and clean them up yourself when
  done — revoking a Hitchhiker and deleting a trip are both intentionally
  easy/safe to test with here.
- **Check persisted state before acting on it**, don't assume. `ensureWorkMode`
  does this correctly — use it rather than a bare toggle tap.
- **An irreversible action (e.g. publishing a trip to Discord — sorry,
  Discover) needs a human's explicit go-ahead first**, every time, not just
  the first time. Don't automate past a confirmation dialog for anything the
  app itself describes as permanent.
- If a script's result looks wrong or surprising, stop and screenshot the
  *actual* current state before doing anything else — don't chain more
  actions hoping it self-corrects.

## Known limitations

- No accessibility/semantics tree is enabled, so there's no DOM to query by
  text/role — Flutter web's CanvasKit renderer draws everything to a single
  `<canvas>`. Every interaction is a raw pixel-coordinate tap. This is why
  `driver.js`'s `tap()` needs an explicit press duration (Playwright's
  zero-delay `.click()` often registers as a hover, not a tap, under
  CanvasKit).
- Custom URL schemes (`kumo://...`) aren't testable this way — they're not
  registered for web, only iOS/Android (see `macos/`/`ios/Runner/Info.plist`).
- Bugs that only manifest on native iOS/Android/macOS builds (vs. this
  environment's web build) won't be caught here. Two of the four bugs found
  2026-08-13 were CanvasKit-web-specific in their *symptom* (an infinite-
  width crash, a PostgREST embed error) but not in their *root cause* — the
  underlying code defect would affect every platform even if the visible
  failure mode differs. Don't assume "not reproducible here" means
  "not a bug."
