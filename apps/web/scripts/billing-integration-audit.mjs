import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const failures = [];

const must = (file, text) => {
  if (!read(file).includes(text)) failures.push(`${file}: missing ${JSON.stringify(text)}`);
};
const forbid = (file, text) => {
  if (read(file).includes(text)) failures.push(`${file}: forbidden ${JSON.stringify(text)}`);
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

must("src/lib/app-config.ts", "VITE_BILLING_CHECKOUT_ENABLED");
must("src/lib/app-config.ts", "billingCheckoutEnabled");
must(".env.example", "VITE_BILLING_CHECKOUT_ENABLED=false");

for (const text of [
  "paymentOrders",
  "paymentOrder:",
  "usePaymentOrdersData",
  "usePaymentOrderData",
  "2500",
]) {
  must("src/hooks/use-domain-data.ts", text);
}

for (const text of [
  "useBillingCheckoutMutation",
  "createPaymentOrder",
  "createCheckout",
  "idempotencyKey()",
  'new URL("/billing/success"',
  "order_id",
  "validatedCheckoutUrl",
  "useBillingReturnOrder",
  "creditBalance",
  "creditTransactions",
]) {
  must("src/hooks/use-billing.ts", text);
}

const billing = block(
  "src/components/app-pages.tsx",
  "function CreditBillingPage",
  "function DemoBillingPage",
);
for (const text of [
  "usePaymentOrdersData()",
  "useBillingCheckoutMutation()",
  "billingCheckoutEnabled",
  "Buy credits",
  "Purchase history",
  "window.location.assign",
  "When do credits arrive?",
]) {
  mustIn("CreditBillingPage", billing, text);
}
for (const text of [
  "Checkout not yet enabled",
  "Upgrade to Pro",
  "Current subscription",
]) {
  forbidIn("CreditBillingPage", billing, text);
}

const returns = block(
  "src/components/app-pages-more.tsx",
  "export function BillingSuccessPage",
  "/* ---------------- Admin: workers",
);
for (const text of [
  "useBillingReturnOrder(orderId)",
  'order.status === "paid"',
  'pluralize(order.credits, "credit")} added',
  "We couldn’t confirm your payment yet",
  "export function BillingCanceledPage",
  "If you completed payment, the credits will be added once it is confirmed",
]) {
  mustIn("Billing return pages", returns, text);
}
for (const text of [
  "You’re on Pro",
  "50 recording hours",
  "you weren’t charged",
]) {
  forbidIn("Billing return pages", returns, text);
}

for (const route of [
  "src/routes/billing.success.tsx",
  "src/routes/billing.canceled.tsx",
]) {
  must(route, "validateSearch");
  must(route, "order_id");
}

const webFiles = [
  "src/hooks/use-billing.ts",
  "src/components/app-pages.tsx",
  "src/components/app-pages-more.tsx",
  "src/repositories/api.ts",
].map(read).join("\n");
for (const secretOrDirectProvider of [
  "api.lemonsqueezy.com",
  "PAYMENT_PROVIDER_API_KEY",
  "PAYMENT_WEBHOOK_SECRET",
  "LEMON_SQUEEZY_STORE_ID",
  "LEMON_SQUEEZY_VARIANT_ID",
]) {
  if (webFiles.includes(secretOrDirectProvider)) {
    failures.push(`web billing: forbidden provider secret/direct API reference ${secretOrDirectProvider}`);
  }
}


// V2 B7: one-time hour catalog and legal copy must not regress to subscriptions.
for (const text of [
  'name: "Starter"',
  "credits: 3_000",
  "amount_minor: 999",
  'name: "Standard"',
  "credits: 9_000",
  "amount_minor: 2_499",
  'name: "Premium"',
  "credits: 24_000",
  "amount_minor: 5_999",
]) {
  must("src/repositories/demo.ts", text);
}
for (const text of [
  "formatApproxHours",
  "One-time cloud-hour purchases",
  "10 trial credits",
  "App Store or Google Play",
]) {
  must("src/components/app-pages.tsx", text);
}
for (const text of [
  "Manage subscription",
  "Cancel subscription",
  "Resume subscription",
  "Pro · Monthly",
]) {
  forbid("src/components/app-pages.tsx", text);
}
for (const text of [
  'h: t("Free mobile advertising")',
  'h: t("Advertising in the Free mobile app")',
  "App Store or Google Play",
  "push token",
]) {
  must("src/components/app-pages-more.tsx", text);
}
must("src/lib/preferences.tsx", 'useState<Language>("en")');
must("src/lib/preferences.tsx", '"The same Starter, Standard, and Premium hour packs');

const deployDocs = read("../../deploy/vps/EXTERNAL_PROVIDERS.md");
for (const text of [
  "Lemon Squeezy Test Mode",
  "VITE_BILLING_CHECKOUT_ENABLED=true",
  "Do **not** enable",
  "Live Mode",
]) {
  if (!deployDocs.includes(text)) failures.push(`staging docs: missing ${JSON.stringify(text)}`);
}

if (failures.length) {
  console.error("Billing integration audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Billing integration audit passed.");
