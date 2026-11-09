import { createFileRoute } from "@tanstack/react-router";

import { publicMeta } from "@/components/app-pages";
import { VideoDownloaderReportPage } from "@/components/public/video-downloader-report";

export const Route = createFileRoute("/video-downloader_/report")({
  head: () =>
    publicMeta(
      "/video-downloader/report",
      "Video downloader: report / copyright removal",
      "Ask for a TikTok video to be blocked in the SaveStream video downloader.",
    ),
  component: VideoDownloaderReportPage,
});
