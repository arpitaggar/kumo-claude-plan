// Example / template — copy this file to start a new smoke-test script.
// Run: node example_login_and_home.js
const { launch, login, goHome, screenshot, AUTH_FILE } = require('./driver');
const fs = require('fs');

(async () => {
  const { browser, page } = await launch();

  if (!fs.existsSync(AUTH_FILE)) {
    // First run only — after this, auth.json is reused automatically.
    await login(page, 'you@example.com', 'your-password');
  }

  await goHome(page);
  await screenshot(page, 'home.png');

  await browser.close();
})();
