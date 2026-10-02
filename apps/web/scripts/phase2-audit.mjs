import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");
const failures = [];
const must = (file, text) => {
  const source = read(file);
  if (!source.includes(text)) failures.push(`${file}: missing ${JSON.stringify(text)}`);
};
const forbid = (file, text) => {
  const source = read(file);
  if (source.includes(text)) failures.push(`${file}: forbidden ${JSON.stringify(text)}`);
};

must("src/routes/__root.tsx", 'href="#main-content"');
must("src/routes/__root.tsx", 'id="main-content"');
must("src/lib/app-config.ts", 'requiredRole: "admin"');
must("src/auth/auth-context.tsx", "AuthProvider");
must("src/components/app-components.tsx", 'canSeeAdmin');
must("src/auth/auth-guards.tsx", 'canAccessRoute(access, identity)');
must("src/components/ui/button.tsx", 'data-slot="button"');
must("src/styles.css", "@media (prefers-reduced-motion: reduce)");
must("src/styles.css", "@media (pointer: coarse)");
must("src/lib/route-metadata.ts", '"noindex,nofollow"');
must("src/lib/route-metadata.ts", 'rel: "canonical"');
must("public/robots.txt", "Sitemap:");
must("public/sitemap.xml", "/pricing");
for (const file of [
  "src/routes/index.tsx",
  "src/routes/pricing.tsx",
  "src/routes/privacy.tsx",
  "src/routes/terms.tsx",
  "src/routes/acceptable-use.tsx",
]) must(file, "publicMeta(");
forbid("src/components/app-pages.tsx", "We monitor it 24/7");
forbid("src/components/app-pages.tsx", "Live status is checked continuously.");

if (failures.length) {
  console.error("Phase 2 frontend audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Phase 2 frontend audit passed.");
