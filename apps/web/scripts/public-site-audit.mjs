// Runtime audit of the public site: node scripts/public-site-audit.mjs <origin> [--production]
// Checks public pages render, use the canonical domain, contain no draft or developer copy,
// and (with --production) that http/www/workers.dev redirect to the canonical host.
const args = process.argv.slice(2);
const origin = (args.find((a) => !a.startsWith("--")) ?? "https://savestream.online").replace(
  /\/$/,
  "",
);
const production = args.includes("--production");
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
const FORBIDDEN = [
  "placeholder",
  "Draft —",
  "prototype",
  "to be completed",
  "workers.dev",
  "app.savestream.app",
  "is designed to",
  "backend-authoritative",
  "Backend-authoritative",
  "does not invent",
  "Sign in to view current packages",
  "Live public status is not available yet",
  "Manage subscription",
  "Cancel subscription",
  "Resume subscription",
  "Pro · Monthly",
];
const failures = [];
const fail = (m) => failures.push(m);

const visibleText = (html) =>
  html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&[a-z#0-9]+;/gi, " ")
    .replace(/\s+/g, " ");

for (const p of PUBLIC_PATHS) {
  const response = await fetch(origin + p, { redirect: "manual" });
  if (response.status !== 200) {
    fail(`${p}: expected 200, got ${response.status}`);
    continue;
  }
  const html = await response.text();
  const canonical = html.match(/<link[^>]+rel="canonical"[^>]+href="([^"]+)"/)?.[1];
  const ogUrl = html.match(/<meta[^>]+property="og:url"[^>]+content="([^"]+)"/)?.[1];
  const ogImage = html.match(/<meta[^>]+property="og:image"[^>]+content="([^"]+)"/)?.[1];
  const expected = `${CANONICAL}${p}`;
  if (canonical !== expected) fail(`${p}: canonical ${canonical} != ${expected}`);
  if (ogUrl !== expected) fail(`${p}: og:url ${ogUrl} != ${expected}`);
  if (!ogImage?.startsWith(`${CANONICAL}/`)) fail(`${p}: og:image ${ogImage} not on ${CANONICAL}`);
  const text = visibleText(html);
  for (const phrase of FORBIDDEN) {
    // Hostnames must not appear anywhere in the HTML; copy only in visible text.
    const found = phrase.includes(".") ? html.includes(phrase) : text.includes(phrase);
    if (found) fail(`${p}: contains ${JSON.stringify(phrase)}`);
  }
}

const notFound = await fetch(`${origin}/this-page-does-not-exist-${Date.now()}`);
const notFoundHtml = await notFound.text();
if (!notFoundHtml.includes("<title>Page not found — SaveStream</title>"))
  fail("404: missing 'Page not found — SaveStream' title");
if (!visibleText(notFoundHtml).includes("Page not found")) fail("404: custom page not rendered");

const status = await fetch(`${origin}/status`, { redirect: "manual" });
if (
  ![301, 302, 307, 308].includes(status.status) ||
  !status.headers.get("location")?.endsWith("/help")
) {
  fail(
    `/status: expected redirect to /help, got ${status.status} ${status.headers.get("location")}`,
  );
}

const favicon = await fetch(`${origin}/favicon.ico`);
const iconType = favicon.headers.get("content-type") ?? "";
if (favicon.status !== 200 || !/icon|image/.test(iconType))
  fail(`/favicon.ico: ${favicon.status} ${iconType}`);

const sitemap = await (await fetch(`${origin}/sitemap.xml`)).text();
for (const p of PUBLIC_PATHS) {
  if (!sitemap.includes(`<loc>${CANONICAL}${p}</loc>`))
    fail(`sitemap.xml: missing ${CANONICAL}${p}`);
}
const robots = await (await fetch(`${origin}/robots.txt`)).text();
if (!robots.includes(`Sitemap: ${CANONICAL}/sitemap.xml`)) fail("robots.txt: wrong sitemap URL");

if (production) {
  const checks = [
    ["http://savestream.online/pricing?x=1", `${CANONICAL}/pricing?x=1`],
    ["https://www.savestream.online/terms", `${CANONICAL}/terms`],
    ["http://www.savestream.online/", `${CANONICAL}/`],
    ["https://savestream.ronganminh221.workers.dev/privacy", `${CANONICAL}/privacy`],
  ];
  for (const [from, to] of checks) {
    const response = await fetch(from, { redirect: "manual" });
    const location = response.headers.get("location");
    if (![301, 308].includes(response.status) || location !== to) {
      fail(`redirect ${from}: expected 301 -> ${to}, got ${response.status} ${location}`);
    }
  }
}

if (failures.length) {
  console.error(`Public site audit failed for ${origin}:`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}
console.log(
  `Public site audit passed for ${origin}${production ? " (with production redirects)" : ""}.`,
);
