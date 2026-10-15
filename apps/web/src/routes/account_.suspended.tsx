import { createFileRoute } from "@tanstack/react-router";

import { AccountSuspendedPage } from "@/components/account/account-status";
import { meta } from "@/components/app-pages";

export const Route = createFileRoute("/account_/suspended")({
  head: () => meta("Account suspended", "This SaveStream account is suspended."),
  component: AccountSuspendedPage,
});
