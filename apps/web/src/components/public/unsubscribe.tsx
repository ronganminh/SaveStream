import { useState } from "react";
import { Link } from "@tanstack/react-router";
import { Check, MailX } from "lucide-react";

import { apiClient } from "@/api/client";
import { authErrorMessage } from "@/api/auth";
import { PublicFooter, PublicHeader } from "@/components/app-pages";
import { Button } from "@/components/ui/button";

type Result = { preference: string; label: string };

/**
 * /unsubscribe?token=… from a notification email. The click only confirms;
 * the switch is turned off by the button (mail scanners that open links
 * don't unsubscribe anyone).
 */
export function UnsubscribePage({ token }: { token: string }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<Result | null>(null);

  const confirm = async () => {
    setBusy(true);
    setError(null);
    try {
      setResult(
        await apiClient.post<Result>("/v1/public/email/unsubscribe", {
          json: { token },
          skipAuth: true,
        }),
      );
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <main className="mx-auto flex max-w-[520px] flex-col items-center gap-4 px-6 pb-24 pt-[152px] text-center">
        <span className="grid size-16 place-items-center rounded-[20px] bg-primary-subtle text-accent-ink">
          {result ? <Check className="size-8" /> : <MailX className="size-8" />}
        </span>
        {result ? (
          <>
            <h1 className="text-[28px] font-extrabold tracking-[-.025em]">You’re unsubscribed</h1>
            <p className="text-muted-foreground">
              We won’t email you about “{result.label}” anymore. Other emails and in-app
              notifications are unchanged.
            </p>
          </>
        ) : (
          <>
            <h1 className="text-[28px] font-extrabold tracking-[-.025em]">
              Unsubscribe from this email?
            </h1>
            <p className="text-muted-foreground">
              Turn off this kind of notification email. Account emails such as email verification
              and password resets are still sent.
            </p>
            {error ? (
              <p role="alert" className="text-sm text-destructive">
                {error}
              </p>
            ) : null}
            <Button size="lg" disabled={busy || !token} onClick={() => void confirm()}>
              {busy ? "Unsubscribing…" : "Unsubscribe"}
            </Button>
          </>
        )}
        <p className="text-sm text-muted-foreground">
          Manage every email in{" "}
          <Link
            to="/settings/notifications"
            className="font-semibold text-accent-ink hover:underline"
          >
            Settings → Notifications
          </Link>
          .
        </p>
      </main>
      <PublicFooter />
    </div>
  );
}
