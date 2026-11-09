import { createFileRoute } from "@tanstack/react-router";

import { publicMeta } from "@/components/app-pages";
import { VideoDownloaderPage } from "@/components/public/video-downloader";

// Not in PUBLIC_INDEXABLE_PATHS or the static sitemap: the page stays noindex
// until the downloader is switched on for good (the kill switch is runtime).
export const Route = createFileRoute("/video-downloader")({
  validateSearch: (search: Record<string, unknown>): { expired?: true } =>
    search["expired"] === "1" || search["expired"] === 1 || search["expired"] === true
      ? { expired: true }
      : {},
  head: () =>
    publicMeta(
      "/video-downloader",
      "Download a TikTok video",
      "Free tool: paste a link to a public TikTok video and save it as MP4 when the creator allows downloads.",
    ),
  component: VideoDownloaderRoute,
});

function VideoDownloaderRoute() {
  const { expired } = Route.useSearch();
  return <VideoDownloaderPage expired={Boolean(expired)} />;
}
