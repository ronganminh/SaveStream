import { createFileRoute } from "@tanstack/react-router";

import { meta } from "@/components/app-pages";
import { UnsubscribePage } from "@/components/public/unsubscribe";

export const Route = createFileRoute("/unsubscribe")({
  validateSearch: (search: Record<string, unknown>): { token?: string } =>
    typeof search["token"] === "string" ? { token: search["token"] } : {},
  head: () => meta("Unsubscribe", "Turn off a kind of SaveStream notification email."),
  component: UnsubscribeRoute,
});

function UnsubscribeRoute() {
  const { token } = Route.useSearch();
  return <UnsubscribePage token={token ?? ""} />;
}
