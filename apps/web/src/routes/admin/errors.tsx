import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { AdminErrorsPage } from "@/components/admin/pages";

export const Route = createFileRoute("/admin/errors")({
  head: () =>
    meta(
      "Audit & operations",
      "Review SaveStream admin audit activity and operational counters.",
    ),
  component: AdminErrorsPage,
});
