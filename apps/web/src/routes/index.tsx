import { createFileRoute } from "@tanstack/react-router";
import { LandingPage } from "@/components/app-pages";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/")({
  head: () => publicMeta("/", "SaveStream — Never miss a TikTok LIVE", "Automatically record the TikTok LIVEs of channels you own or are authorized to record. Cloud recording, no computer left running."),
  component: LandingPage,
});
