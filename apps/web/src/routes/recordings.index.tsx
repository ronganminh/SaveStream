import { createFileRoute, lazyRouteComponent } from "@tanstack/react-router";
import { meta } from "@/components/app-components";

const RecordingsPage = lazyRouteComponent(() => import("@/components/app-pages"), "RecordingsPage");

export const Route = createFileRoute("/recordings/")({
  head: () => meta("Recordings", "Watch and download completed livestream recordings."),
  component: RecordingsPage,
});
