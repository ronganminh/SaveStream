import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();
const preferences = fs.readFileSync(path.join(root, "src/lib/preferences.tsx"), "utf8");
const dictionaryStart = preferences.indexOf("const vi: Record<string, string> = {");
const dictionaryEnd = preferences.indexOf("\ntype Preferences =", dictionaryStart);
const dictionary = preferences.slice(dictionaryStart, dictionaryEnd);
const keys = new Set<string>();
for (const match of dictionary.matchAll(/^\s*(?:"([^"]+)"|([A-Za-z_$][\w$]*))\s*:/gm)) {
  keys.add(match[1] ?? match[2] ?? "");
}

const sourceFiles = [
  "src/components/app-components.tsx",
  "src/components/app-pages.tsx",
  "src/components/app-pages-more.tsx",
  "src/routes/__root.tsx",
];

test("Vietnamese dictionary covers static t() literals in critical UI files", () => {
  const missing = new Set<string>();
  for (const file of sourceFiles) {
    const source = fs.readFileSync(path.join(root, file), "utf8");
    for (const match of source.matchAll(/\bt\(\s*"([^"]+)"\s*\)/g)) {
      if (!keys.has(match[1]!)) missing.add(match[1]!);
    }
  }
  assert.deepEqual([...missing].sort(), []);
});
