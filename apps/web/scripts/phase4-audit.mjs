import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");
const failures = [];
const must = (file, text) => {
  if (!read(file).includes(text)) failures.push(`${file}: missing ${JSON.stringify(text)}`);
};
const forbid = (file, text) => {
  if (read(file).includes(text)) failures.push(`${file}: forbidden ${JSON.stringify(text)}`);
};

must("src/components/app-pages.tsx", "width={item.width}");
must("src/components/app-pages.tsx", "height={item.height}");
must("src/components/app-pages.tsx", 'loading="lazy"');
must("src/components/app-pages.tsx", 'decoding="async"');
must("src/components/app-pages.tsx", 'preload="metadata"');
must("src/repositories/index.ts", 'import("@/repositories/demo")');
must("src/repositories/index.ts", 'import("@/repositories/api")');
forbid("src/repositories/index.ts", 'import { demoRepositories }');
must("src/lib/analytics-schema.ts", '"landing_cta_clicked"');
must("src/lib/analytics-schema.ts", '"support_opened"');
must("src/lib/analytics-schema.ts", "forbiddenPropertyKey");
must("src/lib/analytics.ts", 'CustomEvent("savestream:analytics"');
forbid("src/lib/analytics.ts", "fetch(");

for (const route of [
  "src/routes/overview.tsx",
  "src/routes/channels.index.tsx",
  "src/routes/recordings.index.tsx",
  "src/routes/usage.tsx",
  "src/routes/admin/system.tsx",
  "src/routes/admin/workers.tsx",
  "src/routes/admin/jobs.index.tsx",
  "src/routes/admin/errors.tsx",
]) {
  must(route, "lazyRouteComponent");
}

must("package.json", '"test:unit"');
must("package.json", '"test:p4"');

if (failures.length) {
  console.error("Phase 4 frontend audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Phase 4 frontend audit passed.");
