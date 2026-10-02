import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { SettingsPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/settings/security")({
  head: () =>
    meta(
      "Security settings",
      "Request a password reset and manage your SaveStream sessions.",
    ),
  component: () => <SettingsPage section="security" />,
});
