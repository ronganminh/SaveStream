import { createFileRoute, lazyRouteComponent } from "@tanstack/react-router";
import { meta } from "@/components/app-components";

const AdminSystemPage = lazyRouteComponent(() => import("@/components/app-pages"), "AdminSystemPage");

export const Route = createFileRoute("/admin/system")({
  head: () => meta("System health", "Monitor recording infrastructure and service health."),
  component: AdminSystemPage,
});
