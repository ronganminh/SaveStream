import { createFileRoute } from "@tanstack/react-router";
import { LandingPage } from "@/components/app-pages";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/")({
  head: () => publicMeta("/", "Automatic TikTok livestream recording", "Monitor authorized TikTok channel workflows and preview automatic cloud recording with SaveStream."),
  component: LandingPage,
});
