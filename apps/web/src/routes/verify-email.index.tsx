import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { VerifyEmailPage } from "@/components/app-pages-more";

export const Route = createFileRoute("/verify-email/")({
  validateSearch: (search: Record<string, unknown>) => ({
    token: typeof search["token"] === "string" ? search["token"] : "",
  }),
  head: () => meta("Check your email", "Verify your email address to activate your SaveStream account."),
  component: VerifyEmailRoute,
});

function VerifyEmailRoute() {
  const { token } = Route.useSearch();
  return <VerifyEmailPage token={token} />;
}
