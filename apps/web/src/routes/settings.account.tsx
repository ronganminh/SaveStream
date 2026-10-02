import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { SettingsPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/settings/account")({
  head: () =>
    meta(
      "Account settings",
      "Update your SaveStream profile, verify your email, export your data, or request account deletion.",
    ),
  component: () => <SettingsPage section="account" />,
});
