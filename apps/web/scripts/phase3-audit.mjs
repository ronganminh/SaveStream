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

must("src/domain/resource-state.ts", 'kind: "loading"');
must("src/domain/resource-state.ts", '"partial"');
must("src/domain/resource-state.ts", '"expiring"');
must("src/repositories/contracts.ts", "interface RecordingRepository");
must("src/repositories/contracts.ts", "interface ChannelRepository");
must("src/repositories/api.ts", "BackendUnavailableError");
must("src/repositories/demo.ts", "demoRepositories");
must("src/hooks/use-domain-data.ts", "toResourceState");
must("src/hooks/use-domain-data.ts", "repositories.recordings.list()");
forbid("src/components/app-pages.tsx", "channels,\n  dailyRecordingHours");
forbid("src/components/app-pages.tsx", "recordings,\n  subscription");
must("src/components/app-pages.tsx", "useRecordingsData");
must("src/components/app-pages.tsx", "useChannelsData");
must("src/components/app-pages.tsx", "useUsageData");

if (failures.length) {
  console.error("Phase 3 frontend audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Phase 3 frontend audit passed.");
