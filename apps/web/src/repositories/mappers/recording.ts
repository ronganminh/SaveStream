import type {
  RecordingResponse,
  RecordingStatusValue,
  WatchResponse,
} from "@/api/types";
import type { RecordingModel, RecordingStatus } from "@/repositories/contracts";

const GB = 1024 ** 3;

function uiStatus(status: RecordingStatusValue): RecordingStatus {
  if (status === "recording" || status === "stop_requested") return "Recording";
  if (status === "completed") return "Ready";
  if (status === "failed") return "Error";
  return "Processing";
}

function formatDuration(seconds: number): string {
  if (seconds <= 0) return "0m";
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (hours > 0) return `${hours}h ${String(minutes).padStart(2, "0")}m`;
  return `${minutes}m`;
}

function formatBytes(bytes: number): { label: string; gb: number } {
  if (bytes <= 0) return { label: "0 GB", gb: 0 };
  const gb = bytes / GB;
  return {
    label: `${gb < 10 ? gb.toFixed(1) : Math.round(gb)} GB`,
    gb: Math.round(gb * 10) / 10,
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
    expires: "—",
    expiresDays: null,
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
