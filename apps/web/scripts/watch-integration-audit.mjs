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
must("src/hooks/use-domain-data.ts", "useEntitlementData");
must("src/hooks/use-channel-mutations.ts", "WATCH_LIMIT_REACHED");
must("src/hooks/use-channel-mutations.ts", "PLAN_REQUIRED");
must("src/lib/tiktok-source.ts", "parseTikTokSource");

const components = "src/components/app-components.tsx";
const addChannel = block(
  components,
  "export function AddChannelDialog",
  "export function UpgradeDialog",
);
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
mustIn("AddChannelDialog", addChannel, "useEntitlementData");
// Auto-record follows the backend can_auto_record (purchase or verified trial).
mustIn("AddChannelDialog", addChannel, "autoRecordAccess(entitlement");
mustIn("AddChannelDialog", addChannel, "auto_record: canAutoRecord && autoRecord");
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
const channelsPage = block(
  pages,
  "export function ChannelsPage",
  "export function ChannelDetailPage",
);
const detailPage = block(
  pages,
  "export function ChannelDetailPage",
  "export function RecordingsPage",
);
const detail = block(pages, "function ChannelDetail({", "function RecordingHeader()");

mustIn("OnboardingPage", onboarding, "useCreateChannelMutation()");
mustIn("OnboardingPage", onboarding, "createChannel.mutateAsync");
forbidIn("OnboardingPage", onboarding, "channels[");
forbidIn("OnboardingPage", onboarding, "setTimeout(");

mustIn("ChannelsPage", channelsPage, "limits.max_watches");
mustIn("ChannelsPage", channelsPage, "watch_count");
// Trial credits and channel limits come from the Admin runtime settings.
mustIn("ChannelsPage", channelsPage, "freeWebSentence(");

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

// Creator avatars: same `creator.avatar_url` as mobile, initials when missing/broken.
must("src/repositories/mappers/channel.ts", "avatarUrl: watch.creator?.avatar_url ?? null");
must(
  "src/repositories/mappers/recording.ts",
  "recording.creator?.avatar_url ?? matchedWatch?.creator?.avatar_url",
);
must("src/components/app-components.tsx", "onError={() => setFailed(true)}");
must("src/components/app-components.tsx", "useCreatorPreview(");
must("src/hooks/use-domain-data.ts", "repositories.recordings.getLiveStatus");
must("src/components/admin/recordings-d3.tsx", "recording.creator?.avatar_url");
must("src/components/admin/user-support.tsx", "item.creator?.avatar_url");

// Channel ownership verification (code in the TikTok bio).
must("src/hooks/use-channel-verification.ts", "/v1/watches/${watchId}/verification");
must("src/hooks/use-channel-verification.ts", "/v1/watches/${watchId}/verification/check");
must("src/components/app/channel-verification.tsx", "Check my bio");
must("src/components/app/channel-verification.tsx", "VERIFICATION_EXPIRED");
must("src/components/app-components.tsx", "<ChannelVerificationCard");
must("src/components/app-pages.tsx", "<ChannelVerificationCard");
must("src/components/app-components.tsx", "Verify to record");
must("src/components/app-components.tsx", "<ChannelVerificationBadge channel={channel}");
must("src/components/app-components.tsx", "export function ChannelVerificationNotice");
must("src/components/app-pages.tsx", "<ChannelVerificationNotice channels={overviewChannels} />");
must("src/components/app-pages.tsx", "<ChannelVerificationNotice channels={channelItems} />");
must("src/repositories/mappers/channel.ts", "verificationRequired: watch.verification_required ?? false");
must("src/components/admin/user-support.tsx", "verifyWatchOwner(item.id, reason)");

if (failures.length) {
  console.error("Watch integration audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Watch integration audit passed.");
