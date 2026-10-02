import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { NotificationsPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/notifications")({
  head: () =>
    meta(
      "Notifications",
      "Review persisted recording lifecycle notifications and durable read state.",
    ),
  component: NotificationsPage,
});
