import { createFileRoute, redirect } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { StatusPage } from "@/components/app-pages-more";
import { isProductionMode } from "@/lib/app-config";

export const Route = createFileRoute("/status")({
  // No public status feed is published yet; production sends visitors to Help.
  beforeLoad: () => {
    if (isProductionMode) throw redirect({ to: "/help", statusCode: 301 });
  },
  head: () => meta("System status", "SaveStream system status."),
  component: StatusPage,
});
