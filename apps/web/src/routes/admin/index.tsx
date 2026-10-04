import { createFileRoute } from "@tanstack/react-router";

import { AdminOverviewD9Page } from "@/components/admin/overview-d9";
import { meta } from "@/components/app-pages";

export const Route = createFileRoute("/admin/")({
  head: () =>
    meta(
      "Admin Overview",
      "Precomputed business and operations reporting for SaveStream.",
    ),
  component: AdminOverviewD9Page,
});
