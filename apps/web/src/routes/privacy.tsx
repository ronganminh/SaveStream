import { createFileRoute } from "@tanstack/react-router";
import { PrivacyPage } from "@/components/app-pages-more";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/privacy")({
  head: () =>
    publicMeta("/privacy", "Privacy Policy", "What SaveStream collects, why, who processes it, and the choices you have."),
  component: () => <PrivacyPage />,
});
