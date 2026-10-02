import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { AdminWorkersPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/admin/workers")({
  head: () =>
    meta(
      "Workers & queues",
      "Aggregate worker-facing operational signals exposed by the SaveStream backend.",
    ),
  component: AdminWorkersPage,
});
