import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const failures = [];
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const exists = (file) => fs.existsSync(path.join(root, file));

function must(file, text) {
  if (!read(file).includes(text)) {
    failures.push(`${file}: missing ${JSON.stringify(text)}`);
  }
}

function forbid(file, text) {
  if (read(file).includes(text)) {
    failures.push(`${file}: forbidden ${JSON.stringify(text)}`);
  }
}

function block(file, start, end) {
  const source = read(file);
  const from = source.indexOf(start);
  const to = source.indexOf(end, from + start.length);
  if (from < 0 || to < 0) {
    failures.push(`${file}: could not locate block ${start}`);
    return "";
  }
  return source.slice(from, to);
}

function mustIn(label, source, text) {
  if (!source.includes(text)) failures.push(`${label}: missing ${JSON.stringify(text)}`);
}

function forbidIn(label, source, text) {
  if (source.includes(text)) failures.push(`${label}: forbidden ${JSON.stringify(text)}`);
}

for (const removed of [
  "src/routes/overview-empty.tsx",
  "src/lib/mock-data.ts",
  "src/lib/plan-catalog.ts",
]) {
  if (exists(removed)) failures.push(`${removed}: obsolete file must stay removed`);
}

must("src/mocks/demo-plan-catalog.ts", 'export type PlanId = "free" | "pro"');
must("src/components/app-pages.tsx", 'from "@/mocks/demo-plan-catalog"');
forbid("src/components/app-pages.tsx", 'from "@/lib/plan-catalog"');
forbid("src/routeTree.gen.ts", "overview-empty");
forbid("src/hooks/use-domain-data.ts", "useNotificationRecordingFeedData");

for (const file of [
  "src/components/app-pages.tsx",
  "src/components/app-pages-more.tsx",
]) {
  const source = read(file);
  if (/\bLegacy[A-Za-z0-9_]*/.test(source)) {
    failures.push(`${file}: Legacy* component naming must be replaced by Demo*`);
  }
}

const overview = block(
  "src/components/app-pages.tsx",
  "function ProductionOverviewPage()",
  "function DemoOverviewPage()",
);
for (const text of [
  "useCreditBalanceData",
  "Available credits",
  "Reserved credits",
  "Monitored channels",
  "Your channels, recordings, and credits at a glance.",
]) {
  mustIn("ProductionOverviewPage", overview, text);
}
for (const text of [
  "12.6 / 50 h",
  "18.4 GB",
  "25% used · resets Oct 1",
  "Sunday, September 27",
]) {
  forbidIn("ProductionOverviewPage", overview, text);
}

const pricing = block(
  "src/components/app-pages.tsx",
  "function CreditPricingPage()",
  "function DemoPricingPage()",
);
for (const text of [
  "Simple, pay-as-you-go pricing",
  "usePublicPricingData()",
  "pricing.packages.map",
]) {
  mustIn("CreditPricingPage", pricing, text);
}
for (const text of ["planList", "planCatalog", "50 recording hours", "Upgrade to Pro"]) {
  forbidIn("CreditPricingPage", pricing, text);
}

const usage = block(
  "src/components/app-pages.tsx",
  "function CreditsUsagePage()",
  "function DemoUsagePage()",
);
for (const text of [
  "Your credit balance, reserved credits, and recording charges.",
  "useCreditBalanceData",
  "useCreditReservationsData",
]) {
  mustIn("CreditsUsagePage", usage, text);
}
for (const text of ["usageStates", "useUsageData", "Recording quota reached"]) {
  forbidIn("CreditsUsagePage", usage, text);
}

const status = block(
  "src/components/app-pages-more.tsx",
  "function ProductionStatusPage()",
  "function DemoStatusPage()",
);
for (const text of [
  "does not currently publish a public live incident feed",
  "does not display illustrative service health",
]) {
  mustIn("ProductionStatusPage", status, text);
}
for (const text of ["publicServices", "Demo data", "Illustrative service state"]) {
  forbidIn("ProductionStatusPage", status, text);
}

const productionHelp = block(
  "src/components/app-pages-more.tsx",
  "const productionHelpTopics",
  "export function HelpPage()",
);
for (const text of [
  'title: "Credits"',
  "bought once and never expiring",
  "Recordings stay in your account until you delete them.",
]) {
  mustIn("productionHelpTopics", productionHelp, text);
}
for (const text of [
  "future API",
  "current frontend values come from one plan catalog",
  "This frontend demo does not connect to a real recorder",
  "Free/Pro",
  "backend-authoritative",
]) {
  forbidIn("productionHelpTopics", productionHelp, text);
}

must("src/components/app-pages.tsx", "Pay as you go with credits.");
must(
  "src/components/app-pages.tsx",
  "SaveStream watches the TikTok channels you are authorized to record",
);

must("src/repositories/index.ts", "isDemoMode ? demoRepositories : apiRepositories");
must("src/lib/app-config.ts", "VITE_APP_MODE must be either demo or production.");

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(full);
    return [full];
  });
}

const srcRoot = path.join(root, "src");
const localStorageUsers = walk(srcRoot)
  .filter((file) => /\.(ts|tsx)$/.test(file))
  .filter((file) => fs.readFileSync(file, "utf8").includes("localStorage"))
  .map((file) => path.relative(root, file).replaceAll("\\", "/"));

const unexpectedStorageUsers = localStorageUsers.filter(
  (file) => file !== "src/lib/preferences.tsx",
);
if (unexpectedStorageUsers.length) {
  failures.push(
    `localStorage is reserved for UI preferences only: ${unexpectedStorageUsers.join(", ")}`,
  );
}

for (const text of [
  "savestream:ui:language",
  "savestream:ui:theme",
  "LEGACY_LANGUAGE_STORAGE_KEY",
  "LEGACY_THEME_STORAGE_KEY",
]) {
  must("src/lib/preferences.tsx", text);
}

if (failures.length) {
  console.error("Phase 13 cleanup audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}

console.log("Phase 13 cleanup audit passed.");
