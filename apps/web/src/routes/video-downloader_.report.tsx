import { createFileRoute } from "@tanstack/react-router";

import { publicMeta } from "@/components/app-pages";
import { JsonLd } from "@/components/public/guides-pages";
import { VideoDownloaderReportPage } from "@/components/public/video-downloader-report";
import { PUBLIC_SITE_URL } from "@/lib/route-metadata";
import { breadcrumbData } from "@/lib/video-downloader";

export const Route = createFileRoute("/video-downloader_/report")({
  head: () =>
    publicMeta(
      "/video-downloader/report",
      "Video downloader: report / copyright removal",
      "Creators and rights holders: ask for a TikTok video to be blocked in the SaveStream video downloader.",
    ),
  component: VideoDownloaderReportRoute,
});

function VideoDownloaderReportRoute() {
  return (
    <>
      <JsonLd
        data={{
          "@context": "https://schema.org",
          ...breadcrumbData(PUBLIC_SITE_URL, [
            ["Video downloader", `${PUBLIC_SITE_URL}/video-downloader`],
            ["Report / copyright removal", `${PUBLIC_SITE_URL}/video-downloader/report`],
          ]),
        }}
      />
      <VideoDownloaderReportPage />
    </>
  );
}
