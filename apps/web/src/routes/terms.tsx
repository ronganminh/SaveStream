import { createFileRoute } from "@tanstack/react-router";
import { TermsPage } from "@/components/app-pages-more";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/terms")({
  head: () => publicMeta("/terms", "Terms of Service", "Draft terms for the SaveStream frontend product preview."),
  component: () => <TermsPage />,
});
