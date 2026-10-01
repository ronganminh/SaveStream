import { createFileRoute, lazyRouteComponent } from "@tanstack/react-router";
import { meta } from "@/components/app-components";

const AdminErrorsPage = lazyRouteComponent(
  () => import("@/components/app-pages-more"),
  "AdminErrorsPage",
);

export const Route = createFileRoute("/admin/errors")({
  head: () => meta("Errors & events", "System error and event log across recording infrastructure."),
  component: AdminErrorsPage,
});
