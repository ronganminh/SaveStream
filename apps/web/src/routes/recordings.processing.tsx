import { createFileRoute } from "@tanstack/react-router";
import { RecordingsProcessingPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/recordings/processing")({
  head: () =>
    meta("Processing recordings", "Recordings being prepared for playback after the LIVE ended."),
  component: RecordingsProcessingPage,
});
