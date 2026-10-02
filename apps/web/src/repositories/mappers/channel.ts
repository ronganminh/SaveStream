import type { RecordingResponse, WatchResponse } from "@/api/types";
import type { ChannelModel, ChannelStatus } from "@/repositories/contracts";

const GB = 1024 ** 3;

function displayName(watch: WatchResponse): string {
  return watch.creator?.display_name || watch.creator?.username || watch.source.value;
}

function handle(watch: WatchResponse): string {
  const username = watch.creator?.username ?? (watch.source.type === "username" ? watch.source.value : "");
  return username ? `@${username.replace(/^@/, "")}` : watch.source.value;
}

function initials(value: string): string {
  const parts = value.trim().split(/\s+/).filter(Boolean).slice(0, 2);
  const result = parts.map((part) => part[0]?.toUpperCase() ?? "").join("");
  return result || "SS";
}

function shortDate(value: string | null): string {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(date);
}

function formatHours(seconds: number): string {
  if (seconds <= 0) return "0 h";
  const hours = seconds / 3600;
  return `${hours < 10 ? hours.toFixed(1) : Math.round(hours)} h`;
}

function formatStorage(bytes: number): string {
  if (bytes <= 0) return "0 GB";
  const gb = bytes / GB;
  return `${gb < 10 ? gb.toFixed(1) : Math.round(gb)} GB`;
}

function statusFor(watch: WatchResponse): ChannelStatus {
  if (watch.status === "paused_error") return "Error";
  if (
    watch.status === "paused" ||
    watch.status === "paused_insufficient_credit" ||
    watch.status === "disabled"
  ) {
    return "Paused";
  }
  if (watch.live_status === "offline") return "Offline";
  return "Waiting";
}

function matchesWatch(recording: RecordingResponse, watch: WatchResponse): boolean {
  const watchUsername = watch.creator?.username?.replace(/^@/, "").toLowerCase();
  const recordingUsername = recording.creator?.username?.replace(/^@/, "").toLowerCase();
  if (watchUsername && recordingUsername) return watchUsername === recordingUsername;
  return (
    recording.source.type === watch.source.type &&
    recording.source.value.replace(/^@/, "").toLowerCase() ===
      watch.source.value.replace(/^@/, "").toLowerCase()
  );
}

function toneFor(id: string): string {
  const tones = [
    "from-avatar-one to-avatar-one-end",
    "from-avatar-two to-avatar-two-end",
    "from-avatar-three to-avatar-three-end",
  ] as const;
  let hash = 0;
  for (const char of id) hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
  return tones[hash % tones.length];
}

export function mapWatchToChannel(
  watch: WatchResponse,
  recordings: readonly RecordingResponse[] = [],
): ChannelModel {
  const related = recordings.filter((recording) => matchesWatch(recording, watch));
  const totalSeconds = related.reduce((sum, recording) => sum + recording.duration_seconds, 0);
  const totalBytes = related.reduce((sum, recording) => sum + recording.bytes_recorded, 0);
  const name = displayName(watch);

  return {
    id: watch.id,
    name,
    handle: handle(watch),
    initials: initials(name),
    platform: "tiktok",
    status: statusFor(watch),
    monitoring: watch.status === "active",
    live: watch.live_status === "live" ? "Live now" : shortDate(watch.last_live_at),
    checked: shortDate(watch.last_checked_at),
    recordings: related.length,
    recordedHours: formatHours(totalSeconds),
    storage: formatStorage(totalBytes),
    tone: toneFor(watch.id),
    backendStatus: watch.status,
    liveStatus: watch.live_status,
    source: watch.source,
    autoRecord: watch.auto_record,
  };
}
