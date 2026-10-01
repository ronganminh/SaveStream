export const channelStatuses = [
  "offline",
  "checking",
  "waiting",
  "live",
  "recording",
  "paused",
  "error",
] as const;
export type ChannelStatus = (typeof channelStatuses)[number];

export const recordingStatuses = [
  "queued",
  "recording",
  "processing",
  "ready",
  "partial",
  "failed",
  "expired",
  "deleting",
] as const;
export type RecordingStatus = (typeof recordingStatuses)[number];

export const quotaStates = ["normal", "warning", "exhausted", "resetting", "unavailable"] as const;
export type QuotaState = (typeof quotaStates)[number];

export const asyncScreenStates = [
  "idle",
  "loading",
  "success",
  "empty",
  "error",
  "retrying",
  "offline",
] as const;
export type AsyncScreenState = (typeof asyncScreenStates)[number];

export type MutationState = "idle" | "pending" | "success" | "error";

export const channelStatusLabels: Record<ChannelStatus, string> = {
  offline: "Offline",
  checking: "Checking",
  waiting: "Waiting",
  live: "Live",
  recording: "Recording",
  paused: "Paused",
  error: "Error",
};

export const recordingStatusLabels: Record<RecordingStatus, string> = {
  queued: "Queued",
  recording: "Recording",
  processing: "Processing",
  ready: "Ready",
  partial: "Partial",
  failed: "Failed",
  expired: "Expired",
  deleting: "Deleting",
};

export type Channel = {
  id: string;
  name: string;
  handle: string;
  initials: string;
  platform: "tiktok";
  status: ChannelStatus;
  monitoring: boolean;
  live: string;
  checked: string;
  recordings: number;
  recordedHours: string;
  storage: string;
  tone: string;
};

export type Recording = {
  id: string;
  channelId: string;
  handle: string;
  title: string;
  date: string;
  time: string;
  duration: string;
  size: string;
  sizeGb: number;
  resolution: string;
  expires: string;
  expiresDays: number | null;
  expireTone?: "warning" | "critical";
  status: RecordingStatus;
  color: string;
  error?: string;
  partialDuration?: string;
};

export type UsageSummary = {
  periodStart: string;
  periodEnd: string;
  resetsOn: string;
  recordingHours: { used: number; limit: number };
  downloadGb: { used: number; limit: number };
  channels: { used: number; limit: number };
  concurrent: { active: number; limit: number };
  retentionDays: number;
  storageGb: number;
  quotaState: QuotaState;
};

export type SupportError = {
  title: string;
  body: string;
  referenceId: string;
  retryable: boolean;
};

export function createSupportReference(prefix = "WEB") {
  const seed = Math.random().toString(36).slice(2, 8).toUpperCase();
  return `${prefix}-${seed}`;
}
