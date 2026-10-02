import type {
  RecordingResponse,
  RecordingStatusValue,
  WatchResponse,
} from "@/api/types";
import type { RecordingModel, RecordingStatus } from "@/repositories/contracts";

const KB = 1024;
const MB = 1024 ** 2;
const GB = 1024 ** 3;

function uiStatus(status: RecordingStatusValue): RecordingStatus {
  if (status === "recording" || status === "stop_requested") return "Recording";
  if (status === "completed") return "Ready";
  if (status === "failed") return "Error";
  return "Processing";
}

export function formatDuration(seconds: number): string {
  if (seconds <= 0) return "0s";
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  if (hours > 0) return `${hours}h ${String(minutes).padStart(2, "0")}m`;
  if (minutes > 0) return `${minutes}m ${String(secs).padStart(2, "0")}s`;
  return `${secs}s`;
}

export function formatBytes(bytes: number): { label: string; gb: number } {
  const gb = bytes / GB;
  const rounded = Math.round(gb * 10) / 10;
  if (bytes <= 0) return { label: "0 MB", gb: 0 };
  if (bytes < MB) return { label: `${Math.max(1, Math.round(bytes / KB))} KB`, gb: rounded };
  if (bytes < GB) {
    const mb = bytes / MB;
    return { label: `${mb < 10 ? mb.toFixed(1) : Math.round(mb)} MB`, gb: rounded };
  }
  return { label: `${gb < 10 ? gb.toFixed(1) : Math.round(gb)} GB`, gb: rounded };
}

const DAY_MS = 86_400_000;

function expiry(expiresAt: string | null | undefined): Pick<
  RecordingModel,
  "expires" | "expiresDays" | "expireTone"
> {
  const time = expiresAt ? Date.parse(expiresAt) : NaN;
  if (!Number.isFinite(time)) return { expires: "—", expiresDays: null };
  const days = Math.max(0, Math.ceil((time - Date.now()) / DAY_MS));
  const label = new Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(
    new Date(time),
  );
  return {
    expires: days <= 1 ? "Tomorrow" : `${days} days (${label})`,
    expiresDays: days,
    ...(days <= 1 ? { expireTone: "critical" as const } : days <= 3 ? { expireTone: "warning" as const } : {}),
  };
}

function recordingDate(recording: RecordingResponse): Date {
  const raw = recording.started_at ?? recording.created_at;
  const date = new Date(raw);
  return Number.isNaN(date.getTime()) ? new Date(0) : date;
}

function handle(recording: RecordingResponse): string {
  const username =
    recording.creator?.username ??
    (recording.source.type === "username" ? recording.source.value : "");
  return username ? `@${username.replace(/^@/, "")}` : recording.source.value;
}

function matchWatch(recording: RecordingResponse, watches: readonly WatchResponse[]): WatchResponse | undefined {
  const username = recording.creator?.username?.replace(/^@/, "").toLowerCase();
  return watches.find((watch) => {
    const watchUsername = watch.creator?.username?.replace(/^@/, "").toLowerCase();
    if (username && watchUsername) return username === watchUsername;
    return (
      recording.source.type === watch.source.type &&
      recording.source.value.replace(/^@/, "").toLowerCase() ===
        watch.source.value.replace(/^@/, "").toLowerCase()
    );
  });
}

function colorFor(id: string): string {
  const colors = [
    "bg-thumbnail-one",
    "bg-thumbnail-two",
    "bg-thumbnail-three",
    "bg-thumbnail-four",
  ] as const;
  let hash = 0;
  for (const char of id) hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
  return colors[hash % colors.length] ?? colors[0];
}

export function mapRecordingToModel(
  recording: RecordingResponse,
  watches: readonly WatchResponse[] = [],
): RecordingModel {
  const date = recordingDate(recording);
  const size = formatBytes(recording.bytes_recorded);
  const matchedWatch = matchWatch(recording, watches);
  const formattedDate = new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
  const formattedTime = new Intl.DateTimeFormat("en", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
  const displayHandle = handle(recording);

  return {
    id: recording.id,
    channelId: matchedWatch?.id ?? "",
    handle: displayHandle,
    title: recording.status === "recording" ? "Live now" : `${formattedDate} livestream`,
    date: formattedDate,
    time: formattedTime,
    duration: formatDuration(recording.duration_seconds),
    size: size.label,
    sizeGb: size.gb,
    resolution: "—",
    ...expiry(recording.expires_at),
    status: uiStatus(recording.status),
    color: colorFor(recording.id),
    ...(recording.error ? { error: recording.error.message } : {}),
    ...(recording.error && recording.duration_seconds > 0
      ? { partialDuration: formatDuration(recording.duration_seconds) }
      : {}),
    backendStatus: recording.status,
    source: recording.source,
    actions: recording.actions,
  };
}
