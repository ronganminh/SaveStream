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

must("src/api/types.ts", "ArtifactResponse");
must("src/api/types.ts", "DownloadUrlResponse");
must("src/repositories/contracts.ts", "listArtifacts(id: string)");
must("src/repositories/contracts.ts", "createArtifactDownloadUrl(artifactId: string)");
must("src/repositories/api.ts", "/artifacts");
must("src/repositories/api.ts", "/download-url");
must("src/hooks/use-domain-data.ts", "recordingArtifacts");
must("src/hooks/use-domain-data.ts", "useRecordingArtifactsData");
must("src/hooks/use-recording-mutations.ts", "useRecordingDownloadMutation");
must("src/hooks/use-recording-mutations.ts", "useDeleteRecordingMutation");
must("src/hooks/use-recording-mutations.ts", "DOWNLOAD_EXPIRY_SAFETY_MS");
must("src/hooks/use-recording-mutations.ts", "createArtifactDownloadUrl");
must("src/hooks/use-recording-mutations.ts", "invalidateQueries({ queryKey: domainQueryKeys.channels })");

const pages = read("src/components/app-pages.tsx");
const detail = block(
  "src/components/app-pages.tsx",
  "export function RecordingDetailPage",
  "function ProcessingTimeline",
);
mustIn("RecordingDetailPage", detail, "useRecordingArtifactsData");
mustIn("RecordingDetailPage", detail, "useRecordingDownloadMutation");
mustIn("RecordingDetailPage", detail, "useDeleteRecordingMutation");
mustIn("RecordingDetailPage", detail, "window.location.assign");
mustIn("RecordingDetailPage", detail, "Recording file unavailable");
mustIn("RecordingDetailPage", detail, "artifactsState.kind === "empty"");
mustIn("RecordingDetailPage", detail, "deleteRecording.mutateAsync");
forbidIn("RecordingDetailPage", detail, "if (!isDemoMode) return;");

const components = read("src/components/app-components.tsx");
const actions = block(
  "src/components/app-components.tsx",
  "function RecordingActions",
  "export function VideoPlayerShell",
);
mustIn("RecordingActions", actions, "useRecordingDownloadMutation");
mustIn("RecordingActions", actions, "useDeleteRecordingMutation");
mustIn("RecordingActions", actions, "window.location.assign");
mustIn("RecordingActions", actions, "recording.actions.can_delete");
forbidIn("RecordingActions", actions, 'toast.success("Download started"');

forbid("src/repositories/api.ts", "@/mocks/fixtures");

if (failures.length) {
  console.error("Recording artifact audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Recording artifact audit passed.");
