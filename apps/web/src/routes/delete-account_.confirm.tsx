import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { DeleteAccountConfirmPage } from "@/components/public/delete-account";

export const Route = createFileRoute("/delete-account_/confirm")({
  validateSearch: (search: Record<string, unknown>): { token?: string } =>
    typeof search["token"] === "string" ? { token: search["token"] } : {},
  head: () => meta("Confirm account deletion", "Confirm deleting your SaveStream account."),
  component: ConfirmRoute,
});

function ConfirmRoute() {
  const { token } = Route.useSearch();
  return <DeleteAccountConfirmPage token={token ?? ""} />;
}
