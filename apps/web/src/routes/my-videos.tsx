import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { MyVideosPage } from "@/components/app/my-videos";

export const Route = createFileRoute("/my-videos")({
  head: () => meta("Download my videos", "Download videos from your verified TikTok channels."),
  component: MyVideosPage,
});
