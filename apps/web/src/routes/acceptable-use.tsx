import { createFileRoute } from "@tanstack/react-router";
import { AcceptableUsePage } from "@/components/app-pages-more";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/acceptable-use")({
  head: () => publicMeta("/acceptable-use", "Acceptable Use Policy", "What you may and may not record with SaveStream, and how we enforce it."),
  component: () => <AcceptableUsePage />,
});
