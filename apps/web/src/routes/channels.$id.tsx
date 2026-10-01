import { createFileRoute, lazyRouteComponent } from "@tanstack/react-router";
import { meta } from "@/components/app-components";

const ChannelDetailPage = lazyRouteComponent(
  () => import("@/components/app-pages"),
  "ChannelDetailPage",
);

export const Route = createFileRoute("/channels/$id")({
  head: () => meta("Channel details", "Review channel monitoring status, activity, and recording history."),
  component: ChannelDetailPage,
});
