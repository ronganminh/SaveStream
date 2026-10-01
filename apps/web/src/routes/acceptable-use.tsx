import { createFileRoute } from "@tanstack/react-router";
import { AcceptableUsePage } from "@/components/app-pages-more";
import { publicMeta } from "@/components/app-pages";

export const Route = createFileRoute("/acceptable-use")({
  head: () => publicMeta("/acceptable-use", "Acceptable Use Policy", "Rules for authorized use of SaveStream recording workflows."),
  component: () => <AcceptableUsePage />,
});
