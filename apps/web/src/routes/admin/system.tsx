import { createFileRoute } from "@tanstack/react-router";

import { AdminSystemPage, meta } from "@/components/app-pages";

export const Route = createFileRoute("/admin/system")({
  head: () =>
    meta(
      "System operations",
      "Backend-authoritative SaveStream operational counters for administrators.",
    ),
  component: AdminSystemPage,
});
