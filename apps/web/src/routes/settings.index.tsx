import { createFileRoute, redirect } from "@tanstack/react-router";

// /settings has no page of its own: it opens the Account tab.
export const Route = createFileRoute("/settings/")({
  beforeLoad: () => {
    throw redirect({ to: "/settings/account", replace: true });
  },
});
