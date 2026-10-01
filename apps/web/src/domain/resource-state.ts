import type { Channel, Recording } from "@/mocks/fixtures";

export type AsyncResourceState<T> =
  | { kind: "loading"; data?: T }
  | { kind: "empty"; data: T }
  | { kind: "success"; data: T }
  | { kind: "stale"; data: T; message?: string }
  | { kind: "error"; data?: T; error: Error };

export type RecordingLifecycle =
  | "waiting"
  | "recording"
  | "processing"
  | "ready"
  | "partial"
  | "failed"
  | "expiring"
  | "expired";

export type ChannelLifecycle = "monitoring" | "live" | "paused" | "offline" | "error";

export function recordingLifecycle(recording: Recording): RecordingLifecycle {
  if (recording.status === "Recording") return "recording";
  if (recording.status === "Processing") return "processing";
  if (recording.status === "Error") {
    return recording.partialDuration ? "partial" : "failed";
  }
  if (recording.expiresDays !== null && recording.expiresDays <= 0) return "expired";
  if (recording.expiresDays !== null && recording.expiresDays <= 3) return "expiring";
  return "ready";
}

export function channelLifecycle(channel: Channel): ChannelLifecycle {
  if (channel.status === "Recording") return "live";
  if (channel.status === "Paused") return "paused";
  if (channel.status === "Error") return "error";
  if (channel.status === "Offline") return "offline";
  return "monitoring";
}

export function isTerminalRecordingLifecycle(state: RecordingLifecycle) {
  return state === "ready" || state === "partial" || state === "failed" || state === "expired";
}
