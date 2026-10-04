import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { AdminJobsPage } from "@/components/admin/pages";

export const Route = createFileRoute("/admin/jobs/")({
  head: () =>
    meta(
      "Recordings & LIVE operations",
      "Administer cloud recordings, watched channels, LIVE detector health, queue pressure, and capacity.",
    ),
  component: AdminJobsPage,
});
