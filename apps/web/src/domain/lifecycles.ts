import type {
  AsyncScreenState,
  ChannelStatus,
  QuotaState,
  RecordingStatus,
} from "@/domain/models";

export const addChannelStates = [
  "empty",
  "invalid",
  "looking_up",
  "found",
  "not_found",
  "already_added",
  "limit_reached",
  "permission_required",
  "adding",
  "success",
  "error",
] as const;
export type AddChannelState = (typeof addChannelStates)[number];

export const recordingLifecycleStates = [
  "waiting_for_live",
  "recording_started",
  "recording_active",
  "stream_ended",
  "processing",
  "ready",
  "partial",
  "processing_failed",
  "expiring_soon",
  "expired",
] as const;
export type RecordingLifecycleState = (typeof recordingLifecycleStates)[number];

export const downloadLifecycleStates = [
  "eligible",
  "preparing",
  "started",
  "quota_insufficient",
  "file_unavailable",
  "network_retry",
] as const;
export type DownloadLifecycleState = (typeof downloadLifecycleStates)[number];

export type LifecycleCopy = {
  title: string;
  body: string;
  cta?: string;
};

export const addChannelCopy: Record<AddChannelState, LifecycleCopy> = {
  empty: {
    title: "Add TikTok channel",
    body: "Enter an authorized TikTok username or profile URL.",
  },
  invalid: {
    title: "Enter a valid TikTok username or URL",
    body: "Use @username or a link like https://www.tiktok.com/@username.",
  },
  looking_up: {
    title: "Looking up creator…",
    body: "Checking the public profile before adding it.",
  },
  found: {
    title: "Profile found",
    body: "Confirm you are authorized to monitor and record this channel.",
    cta: "Continue",
  },
  not_found: {
    title: "We couldn’t find this TikTok account",
    body: "Check the spelling and try again.",
    cta: "Try again",
  },
  already_added: {
    title: "This channel is already monitored",
    body: "Open the existing channel to change monitoring.",
    cta: "View channel",
  },
  limit_reached: {
    title: "Monitored channel limit reached",
    body: "Remove a monitored channel or upgrade your plan.",
    cta: "Upgrade plan",
  },
  permission_required: {
    title: "Confirm authorization",
    body: "Only add channels you own, manage, or have explicit permission to record.",
    cta: "Add & start monitoring",
  },
  adding: {
    title: "Adding channel",
    body: "Saving the channel and enabling monitoring.",
  },
  success: {
    title: "Monitoring started",
    body: "The channel is now waiting for its next livestream.",
    cta: "Go to channels",
  },
  error: {
    title: "Channel couldn’t be added",
    body: "Nothing was changed. Try again using the reference shown below.",
    cta: "Try again",
  },
};

export const recordingLifecycleCopy: Record<RecordingLifecycleState, LifecycleCopy> = {
  waiting_for_live: {
    title: "Waiting for live",
    body: "Monitoring is enabled and waiting for the channel to go live.",
  },
  recording_started: {
    title: "Recording started",
    body: "The livestream was detected and recording has started.",
  },
  recording_active: {
    title: "Recording in progress",
    body: "The live timer and saved bytes update while recording continues.",
  },
  stream_ended: {
    title: "Stream ended",
    body: "Recording has stopped and processing is about to begin.",
  },
  processing: {
    title: "Processing video",
    body: "The recording is being finalized for playback and download.",
  },
  ready: {
    title: "Recording ready",
    body: "The video is ready to watch or download.",
    cta: "Download video",
  },
  partial: {
    title: "Partial recording available",
    body: "Part of the livestream was saved and can still be downloaded.",
    cta: "Download partial",
  },
  processing_failed: {
    title: "Processing failed",
    body: "The saved media could not be finalized. Retry processing without double-submitting.",
    cta: "Retry processing",
  },
  expiring_soon: {
    title: "Recording expires soon",
    body: "Download the recording before the retention period ends.",
    cta: "Download",
  },
  expired: {
    title: "Recording expired",
    body: "The retention period ended and the file is no longer available.",
  },
};

export const downloadLifecycleCopy: Record<DownloadLifecycleState, LifecycleCopy> = {
  eligible: {
    title: "Ready to download",
    body: "The recording is available and your download quota is sufficient.",
    cta: "Download video",
  },
  preparing: {
    title: "Preparing download",
    body: "Preparing the file. The download action is temporarily disabled.",
  },
  started: {
    title: "Download started",
    body: "The browser download has started.",
  },
  quota_insufficient: {
    title: "Not enough download quota",
    body: "Upgrade or wait for the monthly quota to reset.",
    cta: "Upgrade plan",
  },
  file_unavailable: {
    title: "File unavailable",
    body: "The file may have expired, been deleted, or not finished processing.",
  },
  network_retry: {
    title: "Network retry",
    body: "The request failed before the download started. Retry when the connection is available.",
    cta: "Try again",
  },
};

export const domainFixtureCatalog = {
  channelStatus: [
    "offline",
    "checking",
    "waiting",
    "live",
    "recording",
    "paused",
    "error",
  ] satisfies ChannelStatus[],
  recordingStatus: [
    "queued",
    "recording",
    "processing",
    "ready",
    "partial",
    "failed",
    "expired",
    "deleting",
  ] satisfies RecordingStatus[],
  quotaState: [
    "normal",
    "warning",
    "exhausted",
    "resetting",
    "unavailable",
  ] satisfies QuotaState[],
  asyncScreenState: [
    "idle",
    "loading",
    "success",
    "empty",
    "error",
    "retrying",
    "offline",
  ] satisfies AsyncScreenState[],
  addChannel: addChannelStates,
  recordingLifecycle: recordingLifecycleStates,
  downloadLifecycle: downloadLifecycleStates,
} as const;
