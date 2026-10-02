import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const failures = [];

const must = (file, text) => {
  if (!read(file).includes(text)) failures.push(`${file}: missing ${JSON.stringify(text)}`);
};
const block = (file, start, end) => {
  const source = read(file);
  const from = source.indexOf(start);
  const to = source.indexOf(end, from + start.length);
  if (from < 0 || to < 0) {
    failures.push(`${file}: could not locate block ${start}`);
    return "";
  }
  return source.slice(from, to);
};
const mustIn = (label, source, text) => {
  if (!source.includes(text)) failures.push(`${label}: missing ${JSON.stringify(text)}`);
};
const forbidIn = (label, source, text) => {
  if (source.includes(text)) failures.push(`${label}: forbidden ${JSON.stringify(text)}`);
};

for (const text of [
  "creditBalance",
  "creditTransactions",
  "creditReservations",
  "pricing",
  "creditPackages",
  "useCreditBalanceData",
  "useCreditTransactionsData",
  "useCreditReservationsData",
  "usePricingData",
  "useCreditPackagesData",
]) {
  must("src/hooks/use-domain-data.ts", text);
}

for (const endpoint of [
  '"/v1/pricing"',
  '"/v1/credits/balance"',
  '"/v1/credits/transactions"',
  '"/v1/credits/reservations"',
  '"/v1/billing/packages"',
]) {
  must("src/repositories/api.ts", endpoint);
}

const pages = "src/components/app-pages.tsx";
const usageWrapper = block(pages, "export function UsagePage", "function formatCreditMoney");
mustIn("UsagePage", usageWrapper, "isDemoMode ? <LegacyUsagePage /> : <CreditsUsagePage />");

const creditsUsage = block(pages, "function CreditsUsagePage", "function LegacyUsagePage");
for (const text of [
  "useCreditBalanceData()",
  "useCreditTransactionsData()",
  "useCreditReservationsData()",
  "usePricingData()",
  "useCreditPackagesData()",
  "Available credits",
  "Posted credits",
  "Reserved credits",
  "Active reservations",
]) {
  mustIn("CreditsUsagePage", creditsUsage, text);
}
for (const text of [
  "recordingHours",
  "downloadGb",
  "periodStart",
  "periodEnd",
  "resetsOn",
  "planCatalog",
  "dailyRecordingHours",
  "Upgrade plan",
]) {
  forbidIn("CreditsUsagePage", creditsUsage, text);
}

const pricing = block(pages, "export function PricingPage", "function LegacyPricingPage");
for (const text of [
  "CreditPricingPage",
  "usePricingData(authenticated)",
  "useCreditPackagesData(authenticated)",
  "Credit-based pricing for livestream recording.",
  "Sign in to view current packages and active pricing",
]) {
  mustIn("PricingPage", pricing, text);
}
for (const text of ["planList.map", "Start with Pro", "Start for free"]) {
  forbidIn("PricingPage", pricing, text);
}

const billing = block(pages, "export function BillingPage", "function LegacyBillingPage");
for (const text of [
  "CreditBillingPage",
  "useCreditBalanceData()",
  "useCreditPackagesData()",
  "Credit packages",
]) {
  mustIn("BillingPage", billing, text);
}
for (const text of ["planCatalog.pro", "Current subscription", "Upgrade to Pro"]) {
  forbidIn("BillingPage", billing, text);
}

if (failures.length) {
  console.error("Credits usage audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Credits usage audit passed.");
