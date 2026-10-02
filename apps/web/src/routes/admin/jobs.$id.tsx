import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { AdminJobDetailPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/admin/jobs/$id")({
  head: () =>
    meta(
      "Recording job detail",
      "Inspect backend-authoritative recording state and supported admin actions.",
    ),
  component: AdminJobDetailPage,
});
