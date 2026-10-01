import { createFileRoute, lazyRouteComponent } from "@tanstack/react-router";
import { meta } from "@/components/app-components";

const UsagePage = lazyRouteComponent(() => import("@/components/app-pages"), "UsagePage");

export const Route = createFileRoute("/usage")({
  head: () => meta("Usage", "Review recording hours, downloads, retention, and monthly plan limits."),
  component: UsagePage,
});
