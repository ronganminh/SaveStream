import { createFileRoute, lazyRouteComponent } from "@tanstack/react-router";
import { meta } from "@/components/app-components";

const ChannelsPage = lazyRouteComponent(() => import("@/components/app-pages"), "ChannelsPage");

export const Route = createFileRoute("/channels/")({
  head: () => meta("Channels", "Manage authorized TikTok channels and automatic monitoring."),
  component: ChannelsPage,
});
