import { createFileRoute } from "@tanstack/react-router";
import { publicMeta } from "@/components/app-pages";
import { HelpCenterPage } from "@/components/public/help-pages";

export const Route = createFileRoute("/help/")({
  head: () =>
    publicMeta("/help", "Help center", "Guides for adding channels, recording LIVEs, downloads, credits and your account.", "help"),
  component: HelpCenterPage,
});
