import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { SettingsPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/settings/notifications")({
  head: () =>
    meta(
      "Notification settings",
      "Review the current SaveStream notification scope and backend limitations.",
    ),
  component: () => <SettingsPage section="notifications" />,
});
