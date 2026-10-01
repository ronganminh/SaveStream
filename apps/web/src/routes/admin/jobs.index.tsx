import { createFileRoute, lazyRouteComponent } from "@tanstack/react-router";
import { meta } from "@/components/app-components";

const AdminJobsPage = lazyRouteComponent(
  () => import("@/components/app-pages-more"),
  "AdminJobsPage",
);

export const Route = createFileRoute("/admin/jobs/")({
  head: () => meta("Recording jobs", "Inspect active, completed, stuck, and failed recording jobs."),
  component: AdminJobsPage,
});
