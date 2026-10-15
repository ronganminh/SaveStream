import { createFileRoute } from "@tanstack/react-router";

import { AccountTerminatedPage } from "@/components/account/account-status";
import { meta } from "@/components/app-pages";

export const Route = createFileRoute("/account_/terminated")({
  head: () => meta("Account closed", "This SaveStream account has been closed."),
  component: AccountTerminatedPage,
});
