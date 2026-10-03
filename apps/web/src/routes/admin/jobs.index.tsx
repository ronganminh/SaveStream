import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { AdminJobsPage } from "@/components/admin/pages";

export const Route = createFileRoute("/admin/jobs/")({
  head: () =>
    meta(
      "Recording jobs",
      "Inspect backend recording records and retry supported failed recordings.",
    ),
  component: AdminJobsPage,
});
