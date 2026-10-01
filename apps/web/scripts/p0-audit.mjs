import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");
const files = [
  "src/components/app-components.tsx",
  "src/components/app-pages.tsx",
  "src/components/app-pages-more.tsx",
  "src/lib/preferences.tsx",
  "src/lib/plan-catalog.ts",
  "src/mocks/fixtures.ts",
  "src/routes/status.tsx",
];
const source = Object.fromEntries(files.map((f) => [f, read(f)]));
const all = Object.values(source).join("\n");
const failures = [];
const requireText = (file, text) => {
  if (!source[file].includes(text)) failures.push(`${file}: missing ${JSON.stringify(text)}`);
};
const forbid = (text, label = text) => {
  if (all.includes(text)) failures.push(`forbidden regression: ${label}`);
};

forbid("MutationObserver", "DOM-mutation localization");
forbid("Yearly billing saves 20%", "unapproved annual billing claim");
forbid("Save 20%", "unapproved annual savings claim");
forbid("Updated every minute", "fake live status cadence");
requireText("src/lib/plan-catalog.ts", 'priceMonthlyUsd: 9.99');
requireText("src/lib/plan-catalog.ts", 'priceYearlyUsd: null');
requireText("src/lib/plan-catalog.ts", 'monitoredChannels: 5');
requireText("src/lib/plan-catalog.ts", 'simultaneousRecordings: 2');
requireText("src/mocks/fixtures.ts", "planCatalog.pro.quotas.recordingHours");
requireText("src/lib/preferences.tsx", '"Demo — illustrative data"');
requireText("src/lib/preferences.tsx", '"Bản demo — dữ liệu minh họa"');

if (failures.length) {
  console.error("P0 frontend audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("P0 frontend audit passed.");
