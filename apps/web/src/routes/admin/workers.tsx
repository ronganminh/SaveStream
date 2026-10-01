import { createFileRoute, lazyRouteComponent } from "@tanstack/react-router";
import { meta } from "@/components/app-components";

const AdminWorkersPage = lazyRouteComponent(
  () => import("@/components/app-pages-more"),
  "AdminWorkersPage",
);

export const Route = createFileRoute("/admin/workers")({
  head: () => meta("Workers", "Recorder and processor worker health and heartbeats."),
  component: AdminWorkersPage,
});
