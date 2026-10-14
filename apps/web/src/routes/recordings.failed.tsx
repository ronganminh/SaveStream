import { createFileRoute } from "@tanstack/react-router";
import { RecordingsFailedPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/recordings/failed")({
  head: () =>
    meta(
      "Failed recordings",
      "Recordings that could not be saved, with the reason and what to do.",
    ),
  component: RecordingsFailedPage,
});
