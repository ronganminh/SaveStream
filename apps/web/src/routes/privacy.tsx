import { createFileRoute } from "@tanstack/react-router";
import { PrivacyPage } from "@/components/app-pages-more";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/privacy")({
  head: () =>
    publicMeta(
      "/privacy",
      "Privacy Policy",
      "What personal information SaveStream collects, how it is used, and your choices.",
    ),
  component: () => <PrivacyPage />,
});
