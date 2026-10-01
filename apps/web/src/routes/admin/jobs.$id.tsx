import { createFileRoute, lazyRouteComponent } from "@tanstack/react-router";
import { meta } from "@/components/app-components";

const AdminJobDetailPage = lazyRouteComponent(
  () => import("@/components/app-pages-more"),
  "AdminJobDetailPage",
);

export const Route = createFileRoute("/admin/jobs/$id")({
  head: () => meta("Job detail", "Timeline, context, and errors for a recording job."),
  component: AdminJobDetailPage,
});
