import { createFileRoute } from "@tanstack/react-router";
import { TermsPage } from "@/components/app-pages-more";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/terms")({
  head: () =>
    publicMeta("/terms", "Terms of Use", "The terms that govern your use of SaveStream’s website and recording service."),
  component: () => <TermsPage />,
});
