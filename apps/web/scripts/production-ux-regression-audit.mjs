import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const failures = [];
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const must = (file, text) => {
  if (!read(file).includes(text)) failures.push(`${file}: missing ${JSON.stringify(text)}`);
};
const forbid = (file, text) => {
  if (read(file).includes(text)) failures.push(`${file}: forbidden ${JSON.stringify(text)}`);
};

const pages = "src/components/app-pages.tsx";
const preferences = "src/lib/preferences.tsx";

// UX-01: the 320px landing preview and CTA must remain width constrained.
must(pages, "max-w-[calc(100%-4.5rem)] truncate");
must(pages, "h-auto max-w-full whitespace-normal");

// UX-02: high-visibility production landing, pricing, status, and auth copy
// stays in place (English only; no translation dictionary).
for (const key of [
  "SaveStream watches the TikTok channels you are authorized to record",
  "Pay as you go with credits.",
  "Simple, pay-as-you-go pricing",
  "Continue with Apple",
  "New to SaveStream?",
]) {
  must(pages, key);
}
must("src/components/public/contact-status.tsx", "does not currently publish a public live incident feed");
forbid(preferences, "const vi:");
must(pages, '{t(copy[0] ?? "")}');
must(pages, 't("Continue with Apple")');

// UX-03: disabled checkout copy must not invite users to pay.
must(pages, "Review credit packages and your balance. Online checkout is not open yet.");
must(
  pages,
  "Preview the available packages. Checkout will become available after payment readiness checks are complete.",
);

// UX-04: mobile payment tabs expose horizontal scrolling and an explicit hint.
must("src/components/admin/payments-d2.tsx", "overflow-x-auto");
must("src/components/admin/payments-d2.tsx", "Swipe horizontally to see all payment sections.");

// UX-05: status is a real public route with canonical metadata and navigation.
must("src/routes/status.tsx", "publicMeta(");
forbid("src/routes/status.tsx", "redirect(");
must("src/lib/app-config.ts", '"/status"');
must("public/sitemap.xml", "https://savestream.online/status");
must(pages, '["/status", "System status"]');

// UX-06: operational alert grammar handles a single order correctly.
must(
  "src/components/admin/overview-d9.tsx",
  'latest.stuck_orders === 1 ? "order is" : "orders are"',
);

// AUTH-01: transient refresh/bootstrap failures must preserve the session.
must("src/api/client.ts", "if (refreshError) throw refreshError");
must("src/auth/auth-context.tsx", "isSessionRejected");
must("src/auth/auth-context.tsx", "retryDelayMs");

if (failures.length) {
  console.error("Production UX regression audit failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Production UX regression audit passed.");
