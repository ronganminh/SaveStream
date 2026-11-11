import { createFileRoute } from "@tanstack/react-router";

import { publicMeta } from "@/components/app-pages";
import { VideoDownloaderPage } from "@/components/public/video-downloader";
import { VIDEO_DOWNLOADER_DESCRIPTION } from "@/lib/video-downloader";

// Indexable (PUBLIC_INDEXABLE_PATHS, public/sitemap.xml) since the downloader
// went live on 2026-11-11. JSON-LD is rendered by the page component.
export const Route = createFileRoute("/video-downloader")({
  validateSearch: (search: Record<string, unknown>): { expired?: true } =>
    search["expired"] === "1" || search["expired"] === 1 || search["expired"] === true
      ? { expired: true }
      : {},
  head: () =>
    publicMeta("/video-downloader", "Free TikTok video downloader", VIDEO_DOWNLOADER_DESCRIPTION),
  component: VideoDownloaderRoute,
});

function VideoDownloaderRoute() {
  const { expired } = Route.useSearch();
  return <VideoDownloaderPage expired={Boolean(expired)} />;
}
