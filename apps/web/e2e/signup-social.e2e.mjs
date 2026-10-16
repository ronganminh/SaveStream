// End-to-end check for P0 2026-10-16: on /sign-up, "Google"/"Apple" must always
// answer. Not ticked: an error right under the buttons, the checkbox scrolled
// into view, focused and highlighted, no OAuth popup. Ticked: the OAuth popup
// opens (the consent is sent with the Firebase token; the API stores it in
// legal_consents, see backend/tests/test_legal_consent.py).
//
// Usage (Playwright is not a dependency of the app):
//   PLAYWRIGHT_MODULE=/path/to/node_modules/playwright/index.mjs \
//   CHROMIUM=/opt/pw-browsers/chromium \
//   node e2e/signup-social.e2e.mjs http://127.0.0.1:5199
// The site needs VITE_FIREBASE_* set (dummy values are fine locally).
const base = (process.argv[2] ?? "http://127.0.0.1:5199").replace(/\/$/, "");
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE ?? "playwright");
const browser = await chromium.launch(
  process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {},
);
const failures = [];
const check = (label, ok) => {
  console.log(`${ok ? "ok  " : "FAIL"} ${label}`);
  if (!ok) failures.push(label);
};

async function page(viewport) {
  const context = await browser.newContext({ viewport });
  const tab = await context.newPage();
  await tab.goto(`${base}/sign-up`, { waitUntil: "load" });
  await tab.getByRole("button", { name: "Google", exact: true }).waitFor();
  await tab.waitForTimeout(1500);
  return { context, tab };
}
const inViewport = (locator) =>
  locator.evaluate((el) => {
    const r = el.getBoundingClientRect();
    return r.top >= 0 && r.bottom <= window.innerHeight;
  });

for (const [provider, viewport] of [
  ["Google", { width: 1366, height: 768 }],
  ["Apple", { width: 390, height: 844 }],
]) {
  const tag = `${provider} ${viewport.width}px`;
  // 1. Nothing ticked: clear feedback, no popup.
  {
    const { context, tab } = await page(viewport);
    const popup = context.waitForEvent("page", { timeout: 2500 }).catch(() => null);
    await tab.getByRole("button", { name: provider, exact: true }).click();
    const alert = tab.locator("#social-consent-error");
    await tab.waitForTimeout(900);
    check(`${tag}: error under the buttons`, await alert.isVisible());
    check(
      `${tag}: error asks to agree to continue`,
      /Please agree to the Terms of Use/.test(
        await alert.innerText({ timeout: 1000 }).catch(() => ""),
      ),
    );
    check(`${tag}: no OAuth popup`, (await popup) === null);
    const agree = tab.locator('input[type="checkbox"]').first();
    check(`${tag}: checkbox scrolled into view`, await inViewport(agree));
    check(`${tag}: checkbox focused`, await agree.evaluate((el) => el === document.activeElement));
    check(`${tag}: checkbox marked invalid`, (await agree.getAttribute("aria-invalid")) === "true");
    await tab.screenshot({
      path: `${process.env.SHOTS ?? "/tmp"}/signup-social-${provider.toLowerCase()}-unticked.png`,
    });

    // 2. Tick both, click again: OAuth starts.
    for (const box of await tab.locator('input[type="checkbox"]').all()) await box.check();
    check(
      `${tag}: message turns into "choose again"`,
      /choose Google or Apple again/.test(await alert.innerText({ timeout: 1000 }).catch(() => "")),
    );
    const popup2 = context.waitForEvent("page", { timeout: 8000 }).catch(() => null);
    await tab.getByRole("button", { name: provider, exact: true }).click();
    const opened = await popup2;
    check(`${tag}: OAuth popup opens after ticking`, opened !== null);
    check(`${tag}: error cleared`, !(await alert.isVisible()));
    await context.close();
  }
}

await browser.close();
if (failures.length) {
  console.error(`\n${failures.length} check(s) failed`);
  process.exit(1);
}
console.log("\nSign-up social e2e passed.");
