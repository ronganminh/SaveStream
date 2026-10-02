import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
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
  if (source.includes(text)) failures.push(`${label}: forbidden ${JSON.stringify(text)}`);
};

must("src/hooks/use-channel-mutations.ts", "useCreateChannelMutation");
must("src/hooks/use-channel-mutations.ts", "usePauseChannelMutation");
must("src/hooks/use-channel-mutations.ts", "useResumeChannelMutation");
must("src/hooks/use-channel-mutations.ts", "useDeleteChannelMutation");
must("src/hooks/use-channel-mutations.ts", "invalidateQueries");
must("src/hooks/use-domain-data.ts", "useChannelData");
must("src/lib/tiktok-source.ts", "parseTikTokSource");

const components = "src/components/app-components.tsx";
const addChannel = block(components, "export function AddChannelDialog", "export function UpgradeDialog");
const channelControls = block(
  components,
  "export function useChannelControls",
  "export function ExpiryText",
);
const commandSearch = block(
  components,
  "export function CommandSearch",
  "export function useChannelControls",
);

mustIn("AddChannelDialog", addChannel, "useCreateChannelMutation()");
mustIn("AddChannelDialog", addChannel, "createChannel.mutateAsync");
mustIn("AddChannelDialog", addChannel, "channelsQuery.data");
forbidIn("AddChannelDialog", addChannel, "channels.find(");
forbidIn("AddChannelDialog", addChannel, "channels.some(");

mustIn("useChannelControls", channelControls, "usePauseChannelMutation()");
mustIn("useChannelControls", channelControls, "useResumeChannelMutation()");
mustIn("useChannelControls", channelControls, "useDeleteChannelMutation()");
forbidIn("useChannelControls", channelControls, "setTimeout(");

mustIn("CommandSearch", commandSearch, "useChannelsData()");
mustIn("CommandSearch", commandSearch, "channelItems.map(");
forbidIn("CommandSearch", commandSearch, "channels.map(");

const pages = "src/components/app-pages.tsx";
const onboarding = block(pages, "export function OnboardingPage", "export function OverviewPage");
const detailPage = block(pages, "export function ChannelDetailPage", "export function RecordingsPage");
const detail = block(pages, "function ChannelDetail({", "function RecordingHeader()");

mustIn("OnboardingPage", onboarding, "useCreateChannelMutation()");
mustIn("OnboardingPage", onboarding, "createChannel.mutateAsync");
forbidIn("OnboardingPage", onboarding, "channels[");
forbidIn("OnboardingPage", onboarding, "setTimeout(");

mustIn("ChannelDetailPage", detailPage, "useChannelData(id)");
mustIn("ChannelDetailPage", detailPage, "useRecordingsData()");
forbidIn("ChannelDetailPage", detailPage, "channels.find(");

mustIn("ChannelDetail", detail, "usePauseChannelMutation()");
mustIn("ChannelDetail", detail, "useResumeChannelMutation()");
mustIn("ChannelDetail", detail, "useDeleteChannelMutation()");
mustIn("ChannelDetail", detail, "onRefresh");
forbidIn("ChannelDetail", detail, "setTimeout(");

must("src/repositories/demo.ts", "demoChannelState");
must("src/repositories/demo.ts", "syncDemoChannel");

if (failures.length) {
  console.error("Watch integration audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Watch integration audit passed.");
