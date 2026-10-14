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
must("src/repositories/contracts.ts", "createArtifactDownloadUrl(");
// QA 2026-10-14: Download must save a named file, not play it in the app tab.
must("src/repositories/api.ts", 'disposition: "attachment"');
must("src/hooks/use-recording-mutations.ts", "export function saveSignedFile");
must("src/repositories/api.ts", "/artifacts");
must("src/repositories/api.ts", "/download-url");
must("src/hooks/use-domain-data.ts", "recordingArtifacts");
must("src/hooks/use-domain-data.ts", "useRecordingArtifactsData");
must("src/hooks/use-recording-mutations.ts", "useRecordingDownloadMutation");
must("src/hooks/use-recording-mutations.ts", "useDeleteRecordingMutation");
must("src/hooks/use-recording-mutations.ts", "DOWNLOAD_EXPIRY_SAFETY_MS");
must("src/hooks/use-recording-mutations.ts", "createArtifactDownloadUrl");
must("src/hooks/use-recording-mutations.ts", "invalidateQueries({ queryKey: domainQueryKeys.channels })");

const detail = block(
  "src/components/app-pages.tsx",
  "export function RecordingDetailPage",
  "function ProcessingTimeline",
);
mustIn("RecordingDetailPage", detail, "useRecordingArtifactsData");
mustIn("RecordingDetailPage", detail, "useRecordingDownloadMutation");
mustIn("RecordingDetailPage", detail, "useDeleteRecordingMutation");
mustIn("RecordingDetailPage", detail, "useRecordingDownload()");
mustIn("RecordingDetailPage", detail, "downloadRecording.start(rec");
forbidIn("RecordingDetailPage", detail, "window.location.assign");
mustIn("RecordingDetailPage", detail, "artifact.width");
mustIn("RecordingDetailPage", detail, "Recording file unavailable");
mustIn("RecordingDetailPage", detail, 'artifactsState.kind === "empty"');
forbidIn("RecordingDetailPage", detail, "if (!isDemoMode) return;");

const actions = block(
  "src/components/app-components.tsx",
  "function RecordingActions",
  "export function VideoPlayerShell",
);
mustIn("RecordingActions", actions, "useRecordingDownload()");
mustIn("RecordingActions", actions, "useDeleteRecordingMutation");
mustIn("RecordingActions", actions, "downloadRecording.start(recording)");

// QA 2026-10-14: Download gave no feedback. The shared hook asks for an
// attachment link, checks storage first, saves without navigating, and shows
// preparing / started / failed-with-retry.
const downloadHook = "src/hooks/use-recording-download.ts";
for (const text of [
  "saveAs: true",
  "checkSignedFile(url)",
  "saveSignedFile(url)",
  '"Preparing download…"',
  '"Download started"',
  '"Download failed"',
  'label: "Try again"',
]) {
  must(downloadHook, text);
}
forbidIn("RecordingActions", actions, "window.location.assign");
mustIn("RecordingActions", actions, "recording.actions.can_delete");

forbid("src/repositories/api.ts", "@/mocks/fixtures");

if (failures.length) {
  console.error("Recording artifact audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Recording artifact audit passed.");
