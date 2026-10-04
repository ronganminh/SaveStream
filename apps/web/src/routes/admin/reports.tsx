import { createFileRoute } from "@tanstack/react-router";

import { AdminReportsD9Page } from "@/components/admin/overview-d9";
import { meta } from "@/components/app-pages";

export const Route = createFileRoute("/admin/reports")({
  head: () =>
    meta(
      "App Reports",
      "Review in-app support reports and diagnostic metadata.",
    ),
  component: AdminReportsD9Page,
});
