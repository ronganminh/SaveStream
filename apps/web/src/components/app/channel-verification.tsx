import { useEffect, useState } from "react";
import { Check, Copy, RefreshCw, ShieldCheck } from "lucide-react";

import { ApiError } from "@/api/errors";
import { Button } from "@/components/ui/button";
import {
  useChannelVerification,
  useChannelVerificationActions,
} from "@/hooks/use-channel-verification";
import { formatDate } from "@/lib/formatters";
import { cn } from "@/lib/utils";

type Props = {
  watchId: string;
  handle: string;
  /** Grace deadline for channels added before verification existed. */
  dueAt?: string | null | undefined;
  /** Show the steps right away (Add channel) instead of a collapsed card. */
  startOpen?: boolean | undefined;
  className?: string | undefined;
};

function resultMessage(
  result: string | null | undefined,
  retryAfter: number | null | undefined,
): { tone: "info" | "warn"; text: string } | null {
  if (result === "code_not_found") {
    return {
      tone: "warn",
      text: "We couldn’t find the code in your bio yet. Save your profile on TikTok, wait a few seconds, then check again.",
    };
  }
  if (result === "retry_later") {
    return {
      tone: "info",
      text: `TikTok didn’t answer this time. Try again${retryAfter ? ` in ${retryAfter} s` : ""}.`,
    };
  }
  return null;
}

/**
 * "Confirm it's your channel": the owner pastes a one-time code anywhere in
 * the TikTok bio and taps Check. Only verified channels are recorded.
 */
export function ChannelVerificationCard({ watchId, handle, dueAt, startOpen, className }: Props) {
  const status = useChannelVerification(watchId);
  const { start, check } = useChannelVerificationActions(watchId);
  const [open, setOpen] = useState(Boolean(startOpen));
  const [copied, setCopied] = useState(false);
  const data = check.data ?? start.data ?? status.data;
  const code = data?.code ?? null;
  const verified = data?.verified ?? false;
  const expired = check.error instanceof ApiError && check.error.code === "VERIFICATION_EXPIRED";

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

  const graceText =
    dueAt && new Date(dueAt).getTime() > Date.now()
      ? `Recording continues until ${formatDate(dueAt, "en")}, then stops until you verify.`
      : "SaveStream records only channels you’ve verified as yours.";
  const message = resultMessage(data?.result, data?.retry_after_seconds);
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
            Confirm {handle} is your channel
          </h3>
          <p className="text-sm text-muted-foreground">{graceText}</p>
        </div>
      </div>

      {!open ? (
        <Button className="self-start" onClick={() => setOpen(true)}>
          Verify channel
        </Button>
      ) : (
        <>
          <p className="text-sm">
            Paste this code anywhere in your TikTok bio, save your profile, then tap Check. You can
            remove it afterwards.
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
          <Button
            className="h-12"
            disabled={!code || check.isPending}
            onClick={() => check.mutate()}
          >
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
