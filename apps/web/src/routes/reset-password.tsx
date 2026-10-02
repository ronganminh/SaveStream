import { createFileRoute } from "@tanstack/react-router";
import { AuthPage, meta } from "@/components/app-pages";

export const Route = createFileRoute("/reset-password")({
  validateSearch: (search: Record<string, unknown>) => ({
    token: typeof search["token"] === "string" ? search["token"] : "",
  }),
  head: () => meta("Choose new password", "Choose a new password for your SaveStream account."),
  component: ResetPasswordRoute,
});

function ResetPasswordRoute() {
  const { token } = Route.useSearch();
  return <AuthPage mode="reset" token={token} />;
}
