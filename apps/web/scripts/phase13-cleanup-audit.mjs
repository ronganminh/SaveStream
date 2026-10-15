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
  // Collapse whitespace so JSX text wrapped by Prettier still matches.
  return source.slice(from, to).replace(/\s+/g, " ");
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
  "export function SectionTitle(",
);
for (const text of [
  "useCreditBalanceData",
  "Credit balance",
  "on hold for live recordings",
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
  "pricing!.packages.map",
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
  "Your credit balance, how you’ve used it, and every change to it.",
  "useCreditBalanceData",
  "useCreditReservationsData",
]) {
  mustIn("CreditsUsagePage", usage, text);
}
for (const text of ["usageStates", "useUsageData", "Recording quota reached"]) {
  forbidIn("CreditsUsagePage", usage, text);
}

const status = block(
  "src/components/public/contact-status.tsx",
  "export function PublicStatusPage()",
  "export function PublicNotFoundPage()",
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

// Help center: Markdown articles in src/content/help (see src/lib/help-content.ts).
const helpDir = path.join(process.cwd(), "src/content/help");
const productionHelp = fs
  .readdirSync(helpDir)
  .filter((name) => name.endsWith(".md"))
  .map((name) => fs.readFileSync(path.join(helpDir, name), "utf8"))
  .join("\n");
for (const text of ["never expire", "{{paid_retention}}", "{{signup_credits}}"]) {
  mustIn("help articles", productionHelp, text);
}
// Numbers that change in Admin come from {{tokens}}, never fixed copy.
for (const text of [
  "stored for 30 days",
  "10 free",
  "future API",
  "This frontend demo does not connect to a real recorder",
  "Free/Pro",
  "backend-authoritative",
  "Retry button",
]) {
  forbidIn("help articles", productionHelp, text);
}
// Every help article is listed in the sitemap.
const sitemap = fs.readFileSync(path.join(process.cwd(), "public/sitemap.xml"), "utf8");
for (const name of fs.readdirSync(helpDir).filter((file) => file.endsWith(".md"))) {
  const url = `https://savestream.online/help/${name.replace(/\.md$/, "")}`;
  if (!sitemap.includes(url)) failures.push(`public/sitemap.xml: missing ${url}`);
}

// Guides (src/content/guides): in the sitemap, numbers from {{tokens}}, permission rule present.
const guidesDir = path.join(process.cwd(), "src/content/guides");
for (const name of fs.readdirSync(guidesDir).filter((file) => file.endsWith(".md"))) {
  const url = `https://savestream.online/guides/${name.replace(/\.md$/, "")}`;
  if (!sitemap.includes(url)) failures.push(`public/sitemap.xml: missing ${url}`);
  const guide = fs.readFileSync(path.join(guidesDir, name), "utf8");
  mustIn(`guide ${name}`, guide, "/acceptable-use");
  mustIn(`guide ${name}`, guide, "/sign-up");
  for (const text of ["stored for 30 days", "10 free", "3 recordings"]) {
    forbidIn(`guide ${name}`, guide, text);
  }
}
for (const page of ["tiktok-live-recorder", "guides"]) {
  const url = `https://savestream.online/${page}`;
  if (!sitemap.includes(url)) failures.push(`public/sitemap.xml: missing ${url}`);
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

for (const text of ["savestream:ui:theme", "LEGACY_THEME_STORAGE_KEY"]) {
  must("src/lib/preferences.tsx", text);
}
// The language switcher was removed (English only); its keys are only cleared.
must("src/lib/preferences.tsx", "RETIRED_LANGUAGE_STORAGE_KEYS");
forbid("src/lib/preferences.tsx", "LANGUAGE_STORAGE_KEY =");

if (failures.length) {
  console.error("Phase 13 cleanup audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}

console.log("Phase 13 cleanup audit passed.");
