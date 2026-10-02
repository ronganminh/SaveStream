import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const failures = [];

const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const must = (file, text) => {
  if (!read(file).includes(text)) {
    failures.push(`${file}: missing ${JSON.stringify(text)}`);
  }
};
const forbid = (file, text) => {
  if (read(file).includes(text)) {
    failures.push(`${file}: forbidden ${JSON.stringify(text)}`);
  }
};

for (const text of [
  "VITE_APP_MODE=production",
  "VITE_API_BASE_URL=https://api.savestream.online",
  "VITE_BILLING_CHECKOUT_ENABLED=false",
]) {
  must(".env.production.example", text);
}

for (const text of [
  "VITE_API_BASE_URL is required when VITE_APP_MODE=production.",
  "VITE_API_BASE_URL must not contain credentials.",
  "VITE_APP_MODE must be either demo or production.",
]) {
  must("src/lib/app-config.ts", text);
}

must("src/hooks/use-billing.ts", 'new URL("/billing/success", window.location.origin)');
must("src/hooks/use-billing.ts", "Hosted checkout must use HTTPS.");
must("src/repositories/api.ts", "json: { return_url: returnUrl }");

const pages = read("src/components/app-pages.tsx");
const googleButton = pages.indexOf("Google sign-in isn’t connected in this prototype.");
const demoAuthGuard = pages.lastIndexOf(
  'isDemoMode && (mode === "sign-in" || mode === "sign-up")',
  googleButton,
);
if (googleButton < 0 || demoAuthGuard < 0 || googleButton - demoAuthGuard > 2500) {
  failures.push(
    "src/components/app-pages.tsx: unsupported Google auth entrypoint must remain demo-only",
  );
}

forbid(".env.production.example", "staging-api.savestream.online");
forbid(".env.production.example", "api-staging.savestream.online");
forbid(".env.production.example", "VITE_APP_MODE=demo");

if (failures.length) {
  console.error("Phase 14 release audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}

console.log("Phase 14 release audit passed.");
