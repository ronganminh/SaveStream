import { createFileRoute } from "@tanstack/react-router";
import { publicMeta } from "@/components/app-pages";
import { GuidesIndexPage } from "@/components/public/guides-pages";

export const Route = createFileRoute("/guides/")({
  head: () =>
    publicMeta(
      "/guides",
      "TikTok LIVE recording guides",
      "Guides for recording your own TikTok LIVEs: manual and automatic methods, saving replays, sales LIVEs and turning streams into clips.",
      "help",
    ),
  component: GuidesIndexPage,
});
