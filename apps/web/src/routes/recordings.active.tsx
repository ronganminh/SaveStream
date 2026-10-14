import { createFileRoute } from "@tanstack/react-router";
import { RecordingsActivePage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/recordings/active")({
  head: () =>
    meta("Active recordings", "Recordings running right now, with elapsed time and a stop button."),
  component: RecordingsActivePage,
});
