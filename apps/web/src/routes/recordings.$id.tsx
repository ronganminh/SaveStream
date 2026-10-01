import { createFileRoute, lazyRouteComponent } from "@tanstack/react-router";
import { meta } from "@/components/app-components";

const RecordingDetailPage = lazyRouteComponent(
  () => import("@/components/app-pages"),
  "RecordingDetailPage",
);

export const Route = createFileRoute("/recordings/$id")({
  head: () => meta("Recording details", "Play, download, and manage a completed livestream recording."),
  component: RecordingDetailPage,
});
