import { createFileRoute } from "@tanstack/react-router";
import { publicMeta } from "@/components/app-pages";
import { StatusPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/status")({
  head: () =>
    publicMeta(
      "/status",
      "System status",
      "Current SaveStream service availability and incident-reporting information.",
    ),
  component: StatusPage,
});
