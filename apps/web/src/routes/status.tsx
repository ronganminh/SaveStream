import { createFileRoute } from "@tanstack/react-router";
import { publicMeta } from "@/components/app-pages";
import { StatusPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/status")({
  head: () =>
    publicMeta("/status", "System status", "Live check of SaveStream services: API, accounts, job queue and recording storage."),
  component: StatusPage,
});
