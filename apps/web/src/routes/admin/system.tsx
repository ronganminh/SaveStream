import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { AdminSystemPage } from "@/components/admin/pages";

export const Route = createFileRoute("/admin/system")({
  head: () =>
    meta(
      "System operations",
      "Backend-authoritative SaveStream operational counters for administrators.",
    ),
  component: AdminSystemPage,
});
