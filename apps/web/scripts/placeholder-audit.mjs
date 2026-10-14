// Fails when a bracketed ALL-CAPS placeholder such as [RESPONSE TIME] would
// reach a page. Run after `npm run build`: it scans the built client and
// server bundles plus the Markdown help content.
//   node scripts/placeholder-audit.mjs
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const PLACEHOLDER = /\[[A-Z]{2,}(?: [A-Z]{2,})*\]/g;
// Library internals that look like placeholders but are never rendered.
const ALLOWED = new Set([
  "[DEFAULT]", // Firebase's default app name
]);
const targets = [".output/public", ".output/server", "src/content"];

function* files(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) yield* files(full);
    else if (/\.(html|js|mjs|md|json|txt|xml)$/.test(entry.name)) yield full;
  }
}

if (!fs.existsSync(path.join(root, ".output"))) {
  console.error("Placeholder audit: run `npm run build` first (.output is missing).");
  process.exit(1);
}

const failures = [];
for (const target of targets) {
  for (const file of files(path.join(root, target))) {
    const text = fs.readFileSync(file, "utf8");
    for (const match of text.matchAll(PLACEHOLDER)) {
      if (ALLOWED.has(match[0])) continue;
      const start = Math.max(0, match.index - 40);
      failures.push(
        `${path.relative(root, file)}: ${match[0]} …${text.slice(start, match.index + match[0].length + 20).replace(/\s+/g, " ")}…`,
      );
    }
  }
}

if (failures.length) {
  console.error("Placeholder audit failed (bracketed placeholders would be shown to visitors):");
  for (const failure of failures.slice(0, 50)) console.error(`- ${failure}`);
  process.exit(1);
}
console.log("Placeholder audit passed.");
