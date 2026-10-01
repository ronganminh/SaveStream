import { createFileRoute, lazyRouteComponent } from "@tanstack/react-router";
import { meta } from "@/components/app-components";

const NotificationsPage = lazyRouteComponent(
  () => import("@/components/app-pages-more"),
  "NotificationsPage",
);

export const Route = createFileRoute("/notifications")({
  head: () => meta("Notifications", "Recording activity, failures, and quota alerts."),
  component: NotificationsPage,
});
