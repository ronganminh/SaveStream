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

must("src/api/sse.ts", "parseSseStream");
must("src/api/sse.ts", 'text/event-stream');
must("src/repositories/api.ts", '"/events"');
must("src/repositories/api.ts", '"Last-Event-ID"');
must("src/repositories/api.ts", "parseSseStream");
must("src/repositories/contracts.ts", "streamEvents(");
must("src/api/types.ts", "RecordingEventResponse");

must("src/hooks/use-recording-realtime.ts", "lastEventIdRef");
must("src/hooks/use-recording-realtime.ts", "streamEvents(recordingId");
must("src/hooks/use-recording-realtime.ts", "reconnecting");
must("src/hooks/use-recording-realtime.ts", "fallback");
must("src/hooks/use-recording-realtime.ts", "invalidateQueries");
must("src/hooks/use-domain-data.ts", "useRecordingData");
must("src/hooks/use-domain-data.ts", "5000");

const pages = "src/components/app-pages.tsx";
const detail = block(pages, "export function RecordingDetailPage", "export function UsagePage");
mustIn("RecordingDetailPage", detail, "useRecordingData(id)");
mustIn("RecordingDetailPage", detail, "useRecordingRealtime");
mustIn("RecordingDetailPage", detail, "useStopRecordingMutation");
mustIn("RecordingDetailPage", detail, "recordingMatchesForcedState");
forbidIn("RecordingDetailPage", detail, "activeRecording");
forbidIn("RecordingDetailPage", detail, "nora-processing");
forbidIn("RecordingDetailPage", detail, "nora-failed");
forbidIn("RecordingDetailPage", detail, "recordings.find(");
forbidIn("RecordingDetailPage", detail, "channels.find(");

const list = block(pages, "export function RecordingsPage", "export function RecordingDetailPage");
mustIn("RecordingsPage", list, "useRecordingsData()");
mustIn("RecordingsPage", list, "isDemoMode");
forbidIn("RecordingsPage", list, 'new Date("Sep 27, 2026").getTime();\n  const list');

const components = "src/components/app-components.tsx";
const activeCard = block(components, "export function ActiveRecordingCard", "export function SearchInput");
mustIn("ActiveRecordingCard", activeCard, "useActiveRecordingData()");
mustIn("ActiveRecordingCard", activeCard, "recording.duration");
mustIn("ActiveRecordingCard", activeCard, "recording.size");
forbidIn("ActiveRecordingCard", activeCard, "Lina Studio");
forbidIn("ActiveRecordingCard", activeCard, "01:42:18");
forbidIn("ActiveRecordingCard", activeCard, "3.8 GB");

forbid("src/components/app-components.tsx", "type Recording,");
forbid("src/components/app-pages.tsx", "activeRecording,");
forbid("src/components/app-pages.tsx", "nora-processing");
forbid("src/components/app-pages.tsx", "nora-failed");

if (failures.length) {
  console.error("Recording realtime audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Recording realtime audit passed.");
