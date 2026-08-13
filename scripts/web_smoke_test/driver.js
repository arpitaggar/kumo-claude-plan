// Reusable Playwright driver for smoke-testing Kumo's Flutter *web* build
// via headless Chrome. See README.md in this directory for why this exists,
// setup, and — importantly — safety rules learned the hard way on
// 2026-08-13 (a real trip got deleted by a careless automated test).

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright-core');

const CHROME_CANDIDATES = [
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
];

function findChrome() {
  const found = CHROME_CANDIDATES.find((p) => fs.existsSync(p));
  if (!found) {
    throw new Error(
      'No Chrome/Chromium binary found at any known path. Edit ' +
        'CHROME_CANDIDATES in driver.js, or install Google Chrome.',
    );
  }
  return found;
}

const AUTH_FILE = path.join(__dirname, 'auth.json');
const DEFAULT_URL = 'http://localhost:8765';
const VIEWPORT = { width: 430, height: 932 }; // phone-sized — matches every
// bug found this session; the app's own default flutter_test surface is
// much wider and doesn't reproduce narrow-viewport layout bugs at all.

/**
 * Launches headless Chrome and a page pointed at the running `flutter run
 * -d web-server` instance. Reuses AUTH_FILE (storageState) if present, so
 * you don't have to re-login every script run.
 *
 * Always attaches console/pageerror listeners that print anything
 * containing "error"/"exception" — every real bug found this session
 * (a RenderFlex overflow, a CanvasKit-only infinite-width crash, two
 * unhandled Dart exceptions) surfaced exactly this way, not through a
 * visual difference alone. Don't remove these listeners in your own scripts.
 */
async function launch({ url = DEFAULT_URL, useAuth = true } = {}) {
  const browser = await chromium.launch({
    executablePath: findChrome(),
    headless: true,
  });
  const contextOpts = { viewport: VIEWPORT };
  if (useAuth && fs.existsSync(AUTH_FILE)) {
    contextOpts.storageState = AUTH_FILE;
  }
  const context = await browser.newContext(contextOpts);
  const page = await context.newPage();

  page.on('console', (msg) => {
    const t = msg.text();
    if (/error|Error|fail|Fail|Exception/.test(t)) {
      console.log('[console]', msg.type(), t);
    }
  });
  page.on('pageerror', (err) => console.log('[pageerror]', err.message));

  await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(3000); // Flutter web's first paint after
  // networkidle still needs real time to boot the Dart runtime + first frame.

  return { browser, context, page };
}

/**
 * A single tap. Flutter web's CanvasKit renderer needs a real press
 * duration between pointerdown/pointerup — a zero-delay Playwright
 * `.click()` registers as a hover (you'll see a tooltip in a screenshot,
 * not a navigation) more often than not. This was the single biggest
 * source of flaky results this session; always use this, never
 * `page.mouse.click(x, y)` directly.
 */
async function tap(page, x, y) {
  await page.mouse.move(x, y);
  await page.waitForTimeout(100);
  await page.mouse.down();
  await page.waitForTimeout(80);
  await page.mouse.up();
  await page.waitForTimeout(500);
}

async function typeText(page, text) {
  await page.keyboard.type(text, { delay: 15 });
}

/** Logs in via the login form. Saves the resulting session to AUTH_FILE. */
async function login(page, email, password) {
  await tap(page, 215, 369); // Email field (login-page coordinates only —
  await typeText(page, email); // do not reuse these numbers on any other
  await tap(page, 215, 431); // screen; every screen's layout is different)
  await typeText(page, password);
  await tap(page, 215, 535); // Sign In
  await page.waitForTimeout(3000);
  await page.context().storageState({ path: AUTH_FILE });
}

/**
 * Reads the *actual persisted* work_mode_<uid> flag from localStorage,
 * not whatever you assume the UI is showing. Every "Work Mode wouldn't
 * turn on" flake this session turned out to be a stale assumption about
 * which state a fresh page load starts from — always check this before
 * deciding whether to tap the toggle, never toggle unconditionally.
 */
async function workModeState(page) {
  const all = await page.evaluate(() =>
    Object.fromEntries(
      Object.keys(localStorage)
        .filter((k) => k.includes('work_mode'))
        .map((k) => [k, localStorage.getItem(k)]),
    ),
  );
  return Object.values(all)[0] === 'true';
}

/**
 * Puts Work Mode into the requested state, checking first so it never
 * blindly toggles (which is exactly how KumoTest got deleted on
 * 2026-08-13 — the script assumed a state instead of checking it, ended up
 * looking at the wrong screen, and a coordinate that was safe on the
 * *intended* screen deleted a real trip on the actual one). Call this
 * before every scenario that depends on a specific mode rather than
 * chaining a bare toggle tap.
 *
 * Assumes you're already on some in-app screen (post-login). Bottom nav
 * coordinates (386,898 Profile / 43,898 Home) are shared across every
 * shell screen, so this is safe to call from anywhere in the shell.
 */
async function ensureWorkMode(page, { on }) {
  await tap(page, 386, 898); // Profile tab
  await page.waitForTimeout(1500);
  const isOn = await workModeState(page);
  if (isOn !== on) {
    await tap(page, 374, 24); // Work Mode banner toggle
    await page.waitForTimeout(1500);
  }
  const confirmed = await workModeState(page);
  if (confirmed !== on) {
    throw new Error(
      `ensureWorkMode({on: ${on}}) failed — persisted state is ` +
        `${confirmed} after toggling. Something is actually broken, not ` +
        'just a timing flake (this check itself waits for the write).',
    );
  }
}

async function goHome(page) {
  await tap(page, 43, 898);
  await page.waitForTimeout(2500);
}

async function screenshot(page, name) {
  const dir = path.join(__dirname, 'screenshots');
  fs.mkdirSync(dir, { recursive: true });
  await page.screenshot({ path: path.join(dir, name) });
}

module.exports = {
  launch,
  tap,
  typeText,
  login,
  workModeState,
  ensureWorkMode,
  goHome,
  screenshot,
  AUTH_FILE,
  VIEWPORT,
};
