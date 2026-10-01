import { createFileRoute, lazyRouteComponent } from "@tanstack/react-router";
import { meta } from "@/components/app-components";

const OverviewPage = lazyRouteComponent(() => import("@/components/app-pages"), "OverviewPage");

export const Route = createFileRoute("/overview")({
  head: () => meta("Overview", "Monitor active cloud recordings, channel health, and monthly usage."),
  component: OverviewPage,
});
