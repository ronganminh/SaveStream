import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const failures = [];
const must = (file, text) => {
  if (!read(file).includes(text)) failures.push(`${file}: missing ${JSON.stringify(text)}`);
};
const forbid = (file, text) => {
  if (read(file).includes(text)) failures.push(`${file}: forbidden ${JSON.stringify(text)}`);
};

for (const state of ["offline","checking","waiting","live","recording","paused","error"]) {
  must("src/domain/models.ts", `"${state}"`);
  must("src/data/mock-repository.ts", `${state}:`);
}
for (const state of ["queued","recording","processing","ready","partial","failed","expired","deleting"]) {
  must("src/domain/models.ts", `"${state}"`);
  must("src/data/mock-repository.ts", `${state}:`);
}
for (const state of ["normal","warning","exhausted","resetting","unavailable"]) {
  must("src/domain/models.ts", `"${state}"`);
  must("src/data/mock-repository.ts", `${state}:`);
}
for (const state of ["idle","loading","success","empty","error","retrying","offline"]) {
  must("src/domain/models.ts", `"${state}"`);
  must("src/data/repository-hooks.tsx", `"${state}"`);
}

must("src/data/repository.ts", "export interface SaveStreamRepository");
must("src/data/repository.ts", "listChannels()");
must("src/data/repository.ts", "listRecordings()");
must("src/data/repository.ts", "lookupChannel(input");
must("src/data/repository.ts", "retryRecordingProcessing");
must("src/data/repository.ts", "prepareDownload");
must("src/routes/__root.tsx", "<RepositoryProvider>");
must("src/components/app-pages.tsx", "useChannelsResource()");
must("src/components/app-pages.tsx", "useRecordingsResource()");
must("src/components/app-pages.tsx", "useRecordingResource(id)");
must("src/components/app-pages.tsx", "useUsageResource()");
must("src/components/app-pages.tsx", 'label="Recording lifecycle"');
must("src/components/app-pages.tsx", 'label="Download lifecycle"');
must("src/components/app-components.tsx", 'useState<AddChannelState>("empty")');
must("src/components/app-components.tsx", '"permission_required"');
must("src/components/app-components.tsx", 'checked={authorized}');
must("src/components/app-components.tsx", 'flow === "adding"');
must("src/components/app-pages.tsx", "disabled={retryingProcessing}");
must("src/components/app-pages.tsx", "referenceId");
must("src/domain/lifecycles.ts", "recordingLifecycleStates");
must("src/domain/lifecycles.ts", "downloadLifecycleStates");
must("src/domain/lifecycles.ts", "addChannelStates");

forbid("src/components/app-components.tsx", "channels as legacyChannels");
forbid("src/components/app-components.tsx", "recordings as legacyRecordings");
forbid("src/components/app-pages.tsx", "channels as legacyChannels");
forbid("src/components/app-pages.tsx", "recordings as legacyRecordings");

if (failures.length) {
  console.error("Phase 3 frontend audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Phase 3 frontend audit passed.");
