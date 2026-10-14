import { createFileRoute, redirect } from "@tanstack/react-router";

// Decision in the design handoff: no separate account summary page.
export const Route = createFileRoute("/account")({
  beforeLoad: () => {
    throw redirect({ to: "/settings/account", replace: true });
  },
});
