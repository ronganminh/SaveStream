import { createFileRoute } from "@tanstack/react-router";
import { publicMeta } from "@/components/app-pages";
import { TikTokLiveRecorderPage } from "@/components/public/tiktok-live-recorder";

export const Route = createFileRoute("/tiktok-live-recorder")({
  head: () =>
    publicMeta(
      "/tiktok-live-recorder",
      "TikTok LIVE recorder",
      "Record TikTok LIVE automatically in the cloud. Add your own channel once and every LIVE is saved as an MP4 — no computer or phone left on.",
    ),
  component: TikTokLiveRecorderPage,
});
