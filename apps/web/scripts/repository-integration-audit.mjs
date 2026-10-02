import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const failures = [];
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

const must = (file, text) => {
  const source = read(file);
  if (!source.includes(text)) failures.push(`${file}: missing ${JSON.stringify(text)}`);
};

const forbid = (file, text, label = text) => {
  const source = read(file);
  if (source.includes(text)) failures.push(`${file}: forbidden ${JSON.stringify(label)}`);
};

const walk = (relativeDir) => {
  const dir = path.join(root, relativeDir);
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const relative = path.join(relativeDir, entry.name);
    return entry.isDirectory() ? walk(relative) : [relative];
  });
};

for (const endpoint of [
  '"/v1/watches"',
  '"/v1/recordings"',
  '"/v1/pricing"',
  '"/v1/credits/balance"',
  '"/v1/billing/packages"',
  '"/v1/me"',
  '"/v1/admin/users"',
  '"/v1/admin/operations/snapshot"',
]) {
  must("src/repositories/api.ts", endpoint);
}

for (const domain of [
  "channels:",
  "recordings:",
  "pricing:",
  "credits:",
  "billing:",
  "users:",
  "admin:",
]) {
  must("src/repositories/api.ts", domain);
  must("src/repositories/demo.ts", domain);
}

must("src/repositories/index.ts", "isDemoMode ? demoRepositories : apiRepositories");
must("src/repositories/api.ts", "UnsupportedBackendCapabilityError");
must("src/repositories/mappers/channel.ts", "mapWatchToChannel");
must("src/repositories/mappers/recording.ts", "mapRecordingToModel");
must("src/api/types.ts", "export type WatchResponse");
must("src/api/types.ts", "export type RecordingResponse");

forbid("src/repositories/api.ts", "BackendUnavailableError");
forbid("src/repositories/api.ts", "@/mocks/fixtures");
forbid("src/repositories/contracts.ts", "@/mocks/fixtures");
forbid("src/repositories/mappers/channel.ts", "@/mocks/fixtures");
forbid("src/repositories/mappers/recording.ts", "@/mocks/fixtures");

for (const file of [...walk("src/components"), ...walk("src/routes")]) {
  if (!/\.(ts|tsx)$/.test(file)) continue;
  const source = read(file);
  if (/\bfetch\s*\(/.test(source)) {
    failures.push(`${file}: forbidden direct fetch call in UI module`);
  }
}

if (failures.length) {
  console.error("Repository integration audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}

console.log("Repository integration audit passed.");
