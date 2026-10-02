import fs from "node:fs";
import path from "node:path";

// Static checks for the Lemon Squeezy resubmission QA (public pricing, legal pages,
// canonical domain, guest API gating). See scripts/public-site-audit.mjs for the
// runtime checks against a deployed or preview site.
const root = process.cwd();
const failures = [];
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const fail = (message) => failures.push(message);
const must = (file, text) => {
  if (!read(file).includes(text)) fail(`${file}: missing ${JSON.stringify(text)}`);
};
const forbid = (file, text) => {
  if (read(file).includes(text)) fail(`${file}: forbidden ${JSON.stringify(text)}`);
};
const between = (text, start, end) => {
  const a = text.indexOf(start);
  const b = text.indexOf(end, a + 1);
  if (a < 0 || b < 0) throw new Error(`markers not found: ${start} … ${end}`);
  return text.slice(a, b);
};

const CANONICAL = "https://savestream.online";
const PUBLIC_PATHS = [
  "/",
  "/pricing",
  "/help",
  "/contact",
  "/terms",
  "/privacy",
  "/acceptable-use",
  "/refund",
];

// Canonical domain everywhere; no Workers hostname or old mockup domain.
const sitemap = read("public/sitemap.xml");
for (const p of PUBLIC_PATHS) {
  if (!sitemap.includes(`<loc>${CANONICAL}${p}</loc>`))
    fail(`sitemap.xml: missing ${CANONICAL}${p}`);
}
must("public/robots.txt", `Sitemap: ${CANONICAL}/sitemap.xml`);
must("src/lib/route-metadata.ts", `|| "${CANONICAL}"`);
for (const file of walk("src").concat(["public/robots.txt", "public/sitemap.xml"])) {
  const text = read(file);
  if (text.includes("workers.dev") && file !== "src/server.ts")
    fail(`${file}: references workers.dev`);
  if (text.includes("app.savestream.app")) fail(`${file}: references app.savestream.app`);
}
must("src/server.ts", "canonicalRedirect(request)");
must("src/server.ts", 'host.endsWith(".workers.dev")');

// Public routes: help is public; refund/contact exist and are indexable.
const config = read("src/lib/app-config.ts");
if (between(config, "const protectedPrefixes", "] as const;").includes('"/help"')) {
  fail("app-config.ts: /help must be a public route");
}
for (const p of PUBLIC_PATHS) {
  if (!between(config, "PUBLIC_INDEXABLE_PATHS", "];").includes(`"${p}"`)) {
    fail(`app-config.ts: ${p} missing from PUBLIC_INDEXABLE_PATHS`);
  }
}
for (const route of [
  "refund",
  "contact",
  "help",
  "pricing",
  "terms",
  "privacy",
  "acceptable-use",
]) {
  if (!fs.existsSync(path.join(root, `src/routes/${route}.tsx`)))
    fail(`missing route src/routes/${route}.tsx`);
}
must("src/routes/status.tsx", 'redirect({ to: "/help"');

// Footer links Refund + Contact and no longer links Status.
const pages = read("src/components/app-pages.tsx");
const footer = between(pages, "export function PublicFooter()", "export function AuthLayout");
for (const link of [
  '"/refund"',
  '"/contact"',
  '"/terms"',
  '"/privacy"',
  '"/acceptable-use"',
  '"/help"',
  '"/pricing"',
]) {
  if (!footer.includes(link)) fail(`PublicFooter: missing ${link}`);
}
if (footer.includes('"/status"')) fail("PublicFooter: must not link /status");

// Legal, refund, contact, help: production copy only.
const more = read("src/components/app-pages-more.tsx");
const legal = between(
  more,
  "/* ---------------- Public: legal, refund, contact",
  "export function StatusPage()",
);
const help = between(more, "const productionHelpTopics", "function DemoHelpPage()");
const forbiddenCopy = [
  "placeholder",
  "Draft",
  "prototype",
  "to be completed",
  "Free and 30 days",
  "renew automatically until",
  "is designed to",
  "backend-authoritative",
  "Backend-authoritative",
  "does not invent",
  "controlled by the backend",
];
for (const [name, text] of [
  ["legal pages", legal],
  ["help page", help],
]) {
  for (const phrase of forbiddenCopy) {
    if (text.includes(phrase)) fail(`${name}: forbidden copy ${JSON.stringify(phrase)}`);
  }
  // Bracketed fill-in text such as "[Company legal name — …]".
  if (/\[[A-Z][a-z]+[^\]]*(?:—|placeholder|legal)[^\]]*\]/.test(text)) {
    fail(`${name}: bracketed placeholder text`);
  }
}
for (const email of [
  "support@savestream.online",
  "privacy@savestream.online",
  "abuse@savestream.online",
]) {
  if (!legal.includes(email)) fail(`legal pages: missing ${email}`);
}
for (const provider of ["Cloudflare", "VNPT", "Brevo", "Lemon Squeezy"]) {
  if (
    !between(legal, "export function PrivacyPage", "export function AcceptableUsePage").includes(
      provider,
    )
  ) {
    fail(`privacy policy: missing service provider ${provider}`);
  }
}

// Production landing + pricing copy: old developer-facing sentences are gone.
for (const phrase of [
  "Sign in to view current packages",
  "We do not show stale Free/Pro prices",
  "Backend monitoring is designed to",
  "Recording workers are designed to start automatically when backend services are connected",
  "backend-authoritative credits instead of the old Free/Pro",
  "does not invent plan-specific retention periods",
  "SaveStream uses integer credits",
  "Production monitoring and recording are designed to run",
]) {
  forbid("src/components/app-pages.tsx", phrase);
}
must("src/components/app-pages.tsx", "usePublicPricingData()");
must("src/repositories/api.ts", '"/v1/public/pricing"');

// Guests never call authenticated APIs: every user-data query is gated.
for (const file of [
  "src/hooks/use-domain-data.ts",
  "src/hooks/use-notifications.ts",
  "src/hooks/use-admin-data.ts",
]) {
  const text = read(file);
  const queries = (text.match(/useQuery\(\{/g) ?? []).length;
  const publicQueries = (text.match(/repositories\.pricing\.getPublic\(\)/g) ?? []).length;
  const gated = (text.match(/useSignedIn\(\);/g) ?? []).length;
  if (queries - publicQueries !== gated) {
    fail(`${file}: ${queries - publicQueries} user-data queries but ${gated} useSignedIn() gates`);
  }
}
must(
  "src/components/app-pages.tsx",
  "{isDemoMode ? <ActiveRecordingCard /> : <RecordingPreviewCard />}",
);

// favicon.ico is a real icon; 404 has its own title.
const ico = fs.readFileSync(path.join(root, "public/favicon.ico"));
if (
  ico.length < 22 ||
  ico.readUInt16LE(0) !== 0 ||
  ico.readUInt16LE(2) !== 1 ||
  ico.readUInt16LE(4) < 1
) {
  fail("public/favicon.ico: not a valid ICO file");
}
must("src/routes/__root.tsx", '"Page not found — SaveStream"');

if (failures.length) {
  console.error("Lemon readiness audit failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}
console.log("Lemon readiness audit passed.");

function walk(dir) {
  return fs.readdirSync(path.join(root, dir), { withFileTypes: true }).flatMap((entry) => {
    const rel = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(rel);
    return /\.(ts|tsx)$/.test(entry.name) && !rel.endsWith("routeTree.gen.ts") ? [rel] : [];
  });
}
