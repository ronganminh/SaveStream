import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

test("shared status badge maps every user-facing channel/recording status", () => {
  const source = fs.readFileSync(
    path.join(process.cwd(), "src/components/app-components.tsx"),
    "utf8",
  );
  const start = source.indexOf("const statusStyles");
  const end = source.indexOf("export function StatusBadge", start);
  const mapping = source.slice(start, end);
  for (const status of [
    "Recording",
    "Processing",
    "Ready",
    "Waiting",
    "Offline",
    "Paused",
    "Error",
  ]) {
    assert.ok(mapping.includes(`${status}:`), `missing status mapping for ${status}`);
  }
});
