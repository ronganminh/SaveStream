// Renders the share images in scripts/og/*.html to public/og/*.png (1200×630).
//   node scripts/render-og.mjs [name ...]     (default: all)
// Uses Playwright's Chromium (preinstalled in CI images and dev containers)
// and only local files: fonts come from apps/mobile/assets/fonts, so the
// output does not depend on the network. Fails if a PNG is 200 KB or more.
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");

const root = process.cwd();
const srcDir = path.join(root, "scripts/og");
const outDir = path.join(root, "public/og");
const LIMIT = 200 * 1024;
const names = process.argv.slice(2).length
  ? process.argv.slice(2)
  : fs
      .readdirSync(srcDir)
      .filter((f) => f.endsWith(".html"))
      .map((f) => f.replace(/\.html$/, ""));

const browser = await chromium.launch();
try {
  const page = await browser.newPage({
    viewport: { width: 1200, height: 630 },
    deviceScaleFactor: 1,
  });
  for (const name of names) {
    await page.goto(pathToFileURL(path.join(srcDir, `${name}.html`)).href);
    await page.evaluate(() => document.fonts.ready);
    const fonts = await page.evaluate(
      () => [...document.fonts].filter((f) => f.status === "loaded").length,
    );
    if (fonts === 0) throw new Error(`${name}: the brand fonts did not load`);
    const out = path.join(outDir, `${name}.png`);
    await page.screenshot({ path: out, type: "png" });
    const size = fs.statSync(out).size;
    console.log(`${path.relative(root, out)}: ${Math.round(size / 1024)} KB`);
    if (size >= LIMIT)
      throw new Error(`${name}.png is ${size} bytes; keep share images under 200 KB`);
  }
} finally {
  await browser.close();
}
