import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");
const files = [
  "src/components/app-components.tsx",
  "src/components/app-pages.tsx",
  "src/components/app-pages-more.tsx",
  "src/lib/preferences.tsx",
  "src/mocks/demo-plan-catalog.ts",
  "src/mocks/fixtures.ts",
  "src/routes/status.tsx",
  "src/lib/app-config.ts",
  "src/api/client.ts",
  "src/api/errors.ts",
  "src/repositories/api.ts",
  "src/repositories/index.ts",
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
const forbidText = (file, text, label = text) => {
  if (source[file].includes(text)) failures.push(`${file}: forbidden ${JSON.stringify(label)}`);
};

forbid("MutationObserver", "DOM-mutation localization");
forbid("Yearly billing saves 20%", "unapproved annual billing claim");
forbid("Save 20%", "unapproved annual savings claim");
forbid("Updated every minute", "fake live status cadence");
requireText("src/mocks/demo-plan-catalog.ts", 'priceMonthlyUsd: 0');
requireText("src/mocks/demo-plan-catalog.ts", 'priceYearlyUsd: null');
requireText("src/mocks/demo-plan-catalog.ts", 'monitoredChannels: 20');
requireText("src/mocks/demo-plan-catalog.ts", 'simultaneousRecordings: 3');
requireText("src/mocks/fixtures.ts", "planCatalog.pro.quotas.recordingHours");
requireText("src/lib/preferences.tsx", '"Demo — illustrative data"');
requireText("src/lib/preferences.tsx", '"Bản demo — dữ liệu minh họa"');

requireText("src/lib/app-config.ts", 'VITE_API_BASE_URL');
requireText("src/lib/app-config.ts", "apiConfigured");
forbidText("src/lib/app-config.ts", "productionBackendConnected = false");
requireText("src/api/client.ts", "REQUEST_ID_HEADER");
requireText("src/api/client.ts", 'credentials = "include"');
requireText("src/api/errors.ts", "export class ApiError");
requireText("src/api/errors.ts", "request_id");
requireText("src/repositories/index.ts", "isDemoMode ? demoRepositories : apiRepositories");
for (const file of ["src/api/client.ts", "src/api/errors.ts", "src/repositories/api.ts"]) {
  forbidText(file, "@/mocks/fixtures", "production foundation importing mock fixtures");
  forbidText(file, "demoRepositories", "production foundation importing demo repositories");
}

if (failures.length) {
  console.error("P0 frontend audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("P0 frontend audit passed.");
