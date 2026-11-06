import { useCallback, useEffect, useState } from "react";
import { Link } from "@tanstack/react-router";
import { Check, Copy, RefreshCw, ShieldCheck } from "lucide-react";
import { toast } from "sonner";

import { ApiError } from "@/api/errors";
import { Button } from "@/components/ui/button";
import {
  useChannelVerification,
  useChannelVerificationActions,
} from "@/hooks/use-channel-verification";
import { channelActionErrorMessage, useUpdateChannelMutation } from "@/hooks/use-channel-mutations";
import {
  AUTO_CHECK_WINDOW_MS,
  LEGACY_ATTESTATION_PROMPT,
  OWNERSHIP_STATEMENT,
  autoCheckDelay,
} from "@/lib/channel-ownership";
import { formatDate } from "@/lib/formatters";
import { cn } from "@/lib/utils";

type Props = {
  watchId: string;
  handle: string;
  /** Grace deadline for channels added before verification existed. */
  dueAt?: string | null | undefined;
  /** Show the steps right away (Add channel) instead of a collapsed card. */
  startOpen?: boolean | undefined;
  /** Verifying is optional (the website accepted the owner's confirmation);
   * it adds a Verified badge. */
  optional?: boolean | undefined;
  className?: string | undefined;
};

function resultMessage(
  result: string | null | undefined,
  autoChecking: boolean,
): { tone: "info" | "warn"; text: string } | null {
  if (result === "code_not_found") {
    return {
      tone: "warn",
      text: autoChecking
        ? "We couldn’t find the code in your bio yet. Save your profile on TikTok — we’ll check again automatically for a few minutes."
        : "We couldn’t find the code in your bio yet. Save your profile on TikTok, wait a few seconds, then check again.",
    };
  }
  // TikTok didn't answer or the last check was moments ago: not an error.
  if (result === "retry_later") {
    return {
      tone: "info",
      text: autoChecking
        ? "Still checking… we’ll try again in a moment."
        : "Still checking… tap Check my bio again in a moment.",
    };
  }
  return null;
}

/**
 * "Confirm it's your channel": the owner pastes a one-time code anywhere in
 * the TikTok bio and taps Check. Required before recording when the API says
 * so (`verification_required`); otherwise optional and gives a Verified badge.
 *
 * While the steps are open, coming back to the tab (after editing the bio on
 * TikTok) checks automatically: at most every 15 s, for at most 5 min, and
 * never sooner than the server's `retry_after_seconds`.
 */
export function ChannelVerificationCard({
  watchId,
  handle,
  dueAt,
  startOpen,
  optional,
  className,
}: Props) {
  const status = useChannelVerification(watchId);
  const { start, check } = useChannelVerificationActions(watchId);
  const [open, setOpen] = useState(Boolean(startOpen));
  const [copied, setCopied] = useState(false);
  const [lastCheckAt, setLastCheckAt] = useState<number | null>(null);
  const [autoUntil, setAutoUntil] = useState<number | null>(null);
  const data = check.data ?? start.data ?? status.data;
  const code = data?.code ?? null;
  const verified = data?.verified ?? false;
  const expired = check.error instanceof ApiError && check.error.code === "VERIFICATION_EXPIRED";
  const canAutoCheck = open && Boolean(code) && !verified && !expired;

  const checkNow = check.mutate;
  const runCheck = useCallback(() => {
    setLastCheckAt(Date.now());
    checkNow();
  }, [checkNow]);

  useEffect(() => {
    // Back from TikTok: start (or restart) the auto-check window.
    if (!canAutoCheck) return;
    const onReturn = () => {
      if (document.visibilityState === "visible") setAutoUntil(Date.now() + AUTO_CHECK_WINDOW_MS);
    };
    document.addEventListener("visibilitychange", onReturn);
    window.addEventListener("focus", onReturn);
    return () => {
      document.removeEventListener("visibilitychange", onReturn);
      window.removeEventListener("focus", onReturn);
    };
  }, [canAutoCheck]);

  useEffect(() => {
    if (!canAutoCheck || autoUntil === null || check.isPending) return;
    const delay = autoCheckDelay({
      now: Date.now(),
      lastCheckAt,
      retryAfterSeconds: check.data?.retry_after_seconds,
      windowEndsAt: autoUntil,
      checksLeft: data?.checks_left,
    });
    if (delay === null) {
      setAutoUntil(null);
      return;
    }
    const timer = window.setTimeout(() => {
      if (document.visibilityState === "visible") runCheck();
    }, delay);
    return () => window.clearTimeout(timer);
  }, [
    autoUntil,
    canAutoCheck,
    check.data?.retry_after_seconds,
    check.isPending,
    data?.checks_left,
    lastCheckAt,
    runCheck,
  ]);

  useEffect(() => {
    // Opening the steps (or an expired code) asks for the current/new code.
    if (open && !verified && !code && !start.isPending && status.isFetched) start.mutate();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, verified, code, status.isFetched]);

  useEffect(() => {
    if (expired) start.mutate();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [expired]);

  if (verified) {
    return (
      <div
        className={cn(
          "flex items-center gap-2 rounded-xl border border-success/30 bg-success-subtle px-3 py-2 text-sm font-semibold text-success",
          className,
        )}
        role="status"
      >
        <ShieldCheck className="size-4" aria-hidden="true" />
        Verified as your channel
      </div>
    );
  }

  const graceText = optional
    ? "Optional. Add a short code to your TikTok bio to get a Verified badge. Verified channels can also be used in the SaveStream app."
    : dueAt && new Date(dueAt).getTime() > Date.now()
      ? `Recording continues until ${formatDate(dueAt, "en")}, then stops until you verify.`
      : "This channel won’t be recorded until you verify it’s yours.";
  const autoChecking = autoUntil !== null;
  const message = resultMessage(data?.result, autoChecking);
  const failed = Boolean(start.error) && !start.isPending;

  return (
    <section
      aria-labelledby={`verify-${watchId}`}
      className={cn(
        "flex flex-col gap-3 rounded-2xl border border-primary/25 bg-primary-subtle p-4",
        className,
      )}
    >
      <div className="flex items-start gap-3">
        <span className="grid size-9 shrink-0 place-items-center rounded-full bg-primary text-primary-foreground">
          <ShieldCheck className="size-4" aria-hidden="true" />
        </span>
        <div className="flex min-w-0 flex-col gap-1">
          <h3 id={`verify-${watchId}`} className="text-[15px] font-extrabold">
            {optional ? `Verify ownership of ${handle}` : `Confirm ${handle} is your channel`}
          </h3>
          <p className="text-sm text-muted-foreground">{graceText}</p>
        </div>
      </div>

      {!open ? (
        <Button
          className="self-start"
          variant={optional ? "outline" : "default"}
          onClick={() => setOpen(true)}
        >
          {optional ? "Verify ownership" : "Verify channel"}
        </Button>
      ) : (
        <>
          <p className="text-sm">
            Paste this code anywhere in your TikTok bio and save your profile. When you come back to
            this tab we check automatically, or tap Check. You can remove it afterwards.
          </p>
          <div className="flex gap-2">
            <div
              className="flex h-12 min-w-0 flex-1 items-center justify-center rounded-xl border border-dashed border-primary bg-surface text-xl font-extrabold tracking-[0.12em]"
              aria-live="polite"
            >
              {code ?? (start.isPending ? "…" : "—")}
            </div>
            <Button
              variant="outline"
              className="h-12"
              disabled={!code}
              onClick={() => {
                if (!code) return;
                void navigator.clipboard?.writeText(code).then(() => setCopied(true));
              }}
            >
              {copied ? <Check aria-hidden="true" /> : <Copy aria-hidden="true" />}
              {copied ? "Copied" : "Copy"}
            </Button>
          </div>
          <Button className="h-12" disabled={!code || check.isPending} onClick={runCheck}>
            {check.isPending ? <RefreshCw className="animate-spin" aria-hidden="true" /> : null}
            {check.isPending ? "Checking your bio…" : "Check my bio"}
          </Button>
          {message ? (
            <p
              role="status"
              className={cn(
                "rounded-xl px-3 py-2 text-sm",
                message.tone === "warn"
                  ? "bg-warning-subtle text-warning"
                  : "bg-surface-2 text-muted-foreground",
              )}
            >
              {message.text}
            </p>
          ) : null}
          {expired ? (
            <p role="status" className="text-sm text-muted-foreground">
              That code expired, so here is a new one. Update your bio with it.
            </p>
          ) : null}
          {failed ? (
            <p role="alert" className="text-sm text-destructive">
              {start.error instanceof ApiError && start.error.code === "RATE_LIMITED"
                ? "Too many codes in the last hour. Try again later."
                : "We couldn’t get a code. Try again."}
            </p>
          ) : null}
          {code && data?.expires_at ? (
            <p className="text-xs text-muted-foreground">
              Code valid until{" "}
              {new Date(data.expires_at).toLocaleTimeString("en", {
                hour: "2-digit",
                minute: "2-digit",
              })}{" "}
              · {data.checks_left} checks left
            </p>
          ) : null}
        </>
      )}
    </section>
  );
}

/**
 * Channels added on the website before the ownership box was required
 * (`ownership_basis: "web_attested_legacy"`): a gentle prompt to tick it.
 * Only a prompt — recording keeps working either way.
 */
export function ChannelAttestationPrompt({
  watchId,
  className,
}: {
  watchId: string;
  className?: string | undefined;
}) {
  const update = useUpdateChannelMutation();
  const [ticked, setTicked] = useState(false);
  const boxId = `attest-${watchId}`;

  const confirm = async () => {
    try {
      await update.mutateAsync({ id: watchId, input: { owner_attested: true } });
      toast.success("Thanks — your confirmation is saved");
    } catch (error) {
      toast.error("Could not save your confirmation", {
        description: channelActionErrorMessage(error),
      });
    }
  };

  return (
    <section
      aria-labelledby={`${boxId}-title`}
      className={cn(
        "flex flex-col gap-3 rounded-[18px] border border-info/25 bg-info-subtle px-5 py-4 md:flex-row md:items-center",
        className,
      )}
    >
      <ShieldCheck className="hidden size-5 shrink-0 text-info md:block" aria-hidden="true" />
      <div className="min-w-0 flex-1 space-y-2">
        <p id={`${boxId}-title`} className="text-sm font-bold">
          {LEGACY_ATTESTATION_PROMPT}
        </p>
        <label htmlFor={boxId} className="flex items-start gap-2.5 text-sm leading-5">
          <input
            id={boxId}
            type="checkbox"
            className="mt-0.5 size-4 shrink-0 accent-primary"
            checked={ticked}
            onChange={(event) => setTicked(event.target.checked)}
          />
          <span>
            {OWNERSHIP_STATEMENT}{" "}
            <Link
              to="/acceptable-use"
              target="_blank"
              className="text-xs font-semibold text-accent-ink underline-offset-2 hover:underline"
            >
              Acceptable Use Policy
            </Link>
          </span>
        </label>
      </div>
      <Button
        size="sm"
        className="self-start md:self-center"
        disabled={!ticked || update.isPending}
        onClick={() => void confirm()}
      >
        {update.isPending ? "Saving…" : "Confirm"}
      </Button>
    </section>
  );
}
