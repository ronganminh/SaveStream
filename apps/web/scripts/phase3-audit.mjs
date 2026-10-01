import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");
const failures = [];

const must = (file, text) => {
  if (!read(file).includes(text)) failures.push(`${file}: missing ${JSON.stringify(text)}`);
};

const block = (file, start, end) => {
  const source = read(file);
  const from = source.indexOf(start);
  const to = source.indexOf(end, from + start.length);
  if (from < 0 || to < 0) {
    failures.push(`${file}: could not locate block ${start}`);
    return "";
  }
  return source.slice(from, to);
};

const mustIn = (label, source, text) => {
  if (!source.includes(text)) failures.push(`${label}: missing ${JSON.stringify(text)}`);
};

const forbidIn = (label, source, text) => {
  if (source.includes(text)) failures.push(`${label}: forbidden direct fixture access ${JSON.stringify(text)}`);
};

must("src/domain/resource-state.ts", 'kind: "loading"');
must("src/domain/resource-state.ts", '"partial"');
must("src/domain/resource-state.ts", '"expiring"');
must("src/repositories/contracts.ts", "interface RecordingRepository");
must("src/repositories/contracts.ts", "interface ChannelRepository");
must("src/repositories/api.ts", "BackendUnavailableError");
must("src/repositories/demo.ts", "demoRepositories");
must("src/hooks/use-domain-data.ts", "toResourceState");
must("src/hooks/use-domain-data.ts", "getRepositories");
must("src/hooks/use-domain-data.ts", ".recordings.list()");

const appPages = "src/components/app-pages.tsx";
const overview = block(appPages, "export function OverviewPage", "export function ChannelsPage");
const channelsPage = block(appPages, "export function ChannelsPage", "export function ChannelDetailPage");
const recordingsPage = block(appPages, "export function RecordingsPage", "export function RecordingDetailPage");
const usagePage = block(appPages, "export function UsagePage", "export function BillingPage");

mustIn("OverviewPage", overview, "useChannelsData()");
mustIn("OverviewPage", overview, "useRecordingsData()");
mustIn("OverviewPage", overview, "overviewChannels");
mustIn("OverviewPage", overview, "overviewRecordings");
forbidIn("OverviewPage", overview, "channels.map(");
forbidIn("OverviewPage", overview, "recordings.slice(");

mustIn("ChannelsPage", channelsPage, "useChannelsData()");
mustIn("ChannelsPage", channelsPage, "channelItems");
mustIn("ChannelsPage", channelsPage, 'channelsState.kind === "loading"');
mustIn("ChannelsPage", channelsPage, 'channelsState.kind === "error"');
forbidIn("ChannelsPage", channelsPage, "channels.filter(");

mustIn("RecordingsPage", recordingsPage, "useRecordingsData()");
mustIn("RecordingsPage", recordingsPage, "recordingItems");
mustIn("RecordingsPage", recordingsPage, "channelItems");
mustIn("RecordingsPage", recordingsPage, 'recordingsState.kind === "loading"');
mustIn("RecordingsPage", recordingsPage, 'recordingsState.kind === "error"');
mustIn("RecordingsPage", recordingsPage, 'recordingsState.kind === "empty"');
forbidIn("RecordingsPage", recordingsPage, "recordings.filter(");
forbidIn("RecordingsPage", recordingsPage, "channels.map(");

mustIn("UsagePage", usagePage, "useUsageData()");
mustIn("UsagePage", usagePage, "usageQuery.data.summary");
mustIn("UsagePage", usagePage, 'usageState.kind === "loading"');
mustIn("UsagePage", usagePage, 'usageState.kind === "error"');

if (failures.length) {
  console.error("Phase 3 frontend audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Phase 3 frontend audit passed.");
