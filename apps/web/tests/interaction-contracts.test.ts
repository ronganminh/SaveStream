import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const read = (file: string) => fs.readFileSync(path.join(process.cwd(), file), "utf8");

test("critical interaction contracts keep pending and accessible controls", () => {
  const components = read("src/components/app-components.tsx");
  const pages = read("src/components/app-pages.tsx");

  assert.ok(components.includes('phase === "submitting"'));
  assert.ok(components.includes('disabled={state !== "found" || phase === "submitting"}'));
  assert.ok(components.includes('aria-label={t("Open menu")}'));
  assert.ok(components.includes('aria-label={t("Close menu")}'));
  assert.ok(pages.includes('aria-pressed={view === "list"}'));
  assert.ok(pages.includes('aria-pressed={view === "grid"}'));
});

test("smoke-route sources exist for public, user, settings, and admin flows", () => {
  for (const route of [
    "src/routes/index.tsx",
    "src/routes/pricing.tsx",
    "src/routes/sign-up.tsx",
    "src/routes/overview.tsx",
    "src/routes/channels.index.tsx",
    "src/routes/recordings.index.tsx",
    "src/routes/usage.tsx",
    "src/routes/settings.account.tsx",
    "src/routes/admin/system.tsx",
  ]) {
    assert.equal(fs.existsSync(path.join(process.cwd(), route)), true, route);
  }
});
