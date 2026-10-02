import { createFileRoute } from "@tanstack/react-router";
import { publicMeta } from "@/components/app-pages";
import { HelpPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/help")({
  head: () =>
    publicMeta(
      "/help",
      "Help",
      "How SaveStream monitoring, cloud recording, credits, and downloads work.",
    ),
  component: HelpPage,
});
