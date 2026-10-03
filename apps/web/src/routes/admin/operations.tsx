import { createFileRoute } from "@tanstack/react-router";

import { AdminOperationsPage } from "@/components/admin/operations-d7";
import { meta } from "@/components/app-pages";

export const Route = createFileRoute("/admin/operations")({
  head: () => meta("Operations", "Storage, email, and broadcast administration."),
  component: AdminOperationsPage,
});
