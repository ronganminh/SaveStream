import { createFileRoute } from "@tanstack/react-router";
import { PrivacyPage } from "@/components/app-pages-more";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/privacy")({
  head: () => publicMeta("/privacy", "Privacy Policy", "Draft information about how SaveStream is intended to handle account data and recordings."),
  component: () => <PrivacyPage />,
});
