import { createFileRoute } from "@tanstack/react-router";
import { TermsPage } from "@/components/app-pages-more";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/terms")({
  head: () =>
    publicMeta(
      "/terms",
      "Terms of Service",
      "Terms for using SaveStream cloud livestream recording, credits, and payments.",
    ),
  component: () => <TermsPage />,
});
