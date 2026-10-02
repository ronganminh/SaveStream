import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { SettingsPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/settings/notifications")({
  head: () =>
    meta(
      "Notification settings",
      "Manage persisted in-app recording notification preferences.",
    ),
  component: () => <SettingsPage section="notifications" />,
});
