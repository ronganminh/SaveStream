import { Link } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { Ban, Mail, PauseCircle } from "lucide-react";

import { PublicFooter, PublicHeader } from "@/components/app-pages";
import { Button } from "@/components/ui/button";
import { SUPPORT_EMAIL, SUPPORT_RESPONSE_TIME } from "@/lib/support";

const STORAGE_KEY = "savestream.accountStatus";

export type AccountStatusDetails = {
  status: "suspended" | "terminated";
  reason: string;
  reference: string;
  since: string;
  email: string;
};

/** Sign-in keeps the 403 details here so the status page can show them. */
export function rememberAccountStatus(details: AccountStatusDetails) {
  try {
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(details));
  } catch {
    // Storage blocked: the page falls back to generic wording.
  }
}

function readAccountStatus(): Partial<AccountStatusDetails> {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as Partial<AccountStatusDetails>) : {};
  } catch {
    return {};
  }
}

/** Read after mount so the server render and first client render match. */
function useAccountStatus(): Partial<AccountStatusDetails> {
  const [details, setDetails] = useState<Partial<AccountStatusDetails>>({});
  useEffect(() => setDetails(readAccountStatus()), []);
  return details;
}

function since(value: string | undefined, withTime: boolean) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    year: "numeric",
    ...(withTime ? { hour: "2-digit", minute: "2-digit", hour12: false, timeZone: "UTC" } : {}),
  }).format(date);
}

function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <main className="mx-auto max-w-[620px] px-6 pb-24 pt-[136px]">
        <section className="flex flex-col gap-5 rounded-[22px] border bg-surface p-7 shadow-card sm:p-9">
          {children}
        </section>
      </main>
      <PublicFooter />
    </div>
  );
}

function ReasonCard({ reason, meta }: { reason?: string | undefined; meta: React.ReactNode }) {
  return (
    <div className="rounded-[14px] bg-surface-2 p-4">
      <p className="text-xs font-bold uppercase tracking-[.08em] text-muted-foreground">Reason</p>
      <p className="mt-1 font-semibold">
        {reason || "A violation of our Terms of Use or Acceptable Use Policy."}
      </p>
      <p className="mt-1.5 text-xs text-muted-foreground">{meta}</p>
    </div>
  );
}

export function AccountSuspendedPage() {
  const details = useAccountStatus();
  const ref = details.reference;
  const subject = ref ? `Appeal ${ref}` : "Appeal";
  const sinceText = since(details.since, true);
  return (
    <Shell>
      <span className="inline-flex h-7 w-fit items-center gap-1.5 rounded-full bg-warning-subtle px-3 text-xs font-bold text-warning-foreground">
        <PauseCircle className="size-3.5" />
        Suspended
      </span>
      <h1 className="text-[30px] font-extrabold leading-tight tracking-[-.03em]">
        Your account is suspended
      </h1>
      <p className="text-muted-foreground">
        We’ve paused this account while we review a report about how it was used.
      </p>
      <ReasonCard
        reason={details.reason}
        meta={
          <>
            {ref ? `Reference ${ref}` : "No reference"}
            {sinceText ? ` · since ${sinceText} UTC` : ""}
          </>
        }
      />
      <ul className="flex list-disc flex-col gap-1.5 pl-5 text-sm">
        <li>Channel monitoring and new recordings are paused.</li>
        <li>Your recordings and credits are kept but can’t be accessed during the suspension.</li>
        <li>
          Read our{" "}
          <Link to="/acceptable-use" className="font-semibold text-accent-ink hover:underline">
            Acceptable Use Policy
          </Link>{" "}
          to see what’s allowed.
        </li>
      </ul>
      <div className="rounded-[14px] border border-primary/25 bg-primary-subtle/60 p-4 text-sm">
        <p className="font-bold">Think this is a mistake?</p>
        <p className="mt-1 text-muted-foreground">
          Appeal by email to <b className="text-foreground">{SUPPORT_EMAIL}</b> with the subject “
          {subject}”. Explain how you own or are authorized to record the channel. We reply within{" "}
          {SUPPORT_RESPONSE_TIME}.
        </p>
      </div>
      <div className="flex flex-wrap gap-2">
        <Button asChild>
          <a href={`mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(subject)}`}>
            <Mail className="size-4" />
            Email an appeal
          </a>
        </Button>
        <Button variant="outline" asChild>
          <Link to="/help/$article" params={{ article: "account-suspended" }}>
            What this means
          </Link>
        </Button>
      </div>
      {details.email ? (
        <p className="text-xs text-muted-foreground">Account: {details.email}</p>
      ) : null}
    </Shell>
  );
}

export function AccountTerminatedPage() {
  const details = useAccountStatus();
  const ref = details.reference;
  const closedOn = since(details.since, false);
  return (
    <Shell>
      <span className="inline-flex h-7 w-fit items-center gap-1.5 rounded-full bg-recording-subtle px-3 text-xs font-bold text-destructive">
        <Ban className="size-3.5" />
        Terminated
      </span>
      <h1 className="text-[30px] font-extrabold leading-tight tracking-[-.03em]">
        This account has been closed
      </h1>
      <p className="text-muted-foreground">
        SaveStream closed this account{closedOn ? ` on ${closedOn}` : ""} for serious or repeated
        violations of our{" "}
        <Link to="/terms" className="font-semibold text-accent-ink hover:underline">
          Terms of Use
        </Link>
        .
      </p>
      <ReasonCard reason={details.reason} meta={ref ? `Reference ${ref}` : "No reference"} />
      <ul className="flex list-disc flex-col gap-1.5 pl-5 text-sm">
        <li>Monitoring has stopped and you can no longer sign in.</li>
        <li>
          Recordings are not deleted early; they expire at the end of their normal retention period.
        </li>
        <li>
          If you have unused paid credits, contact us. Requests are reviewed under the{" "}
          <Link to="/refund" className="font-semibold text-accent-ink hover:underline">
            Refund Policy
          </Link>
          .
        </li>
      </ul>
      <p className="text-sm text-muted-foreground">
        If you believe this was a mistake, email{" "}
        <a
          className="font-semibold text-accent-ink"
          href={`mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(ref ? `Appeal ${ref}` : "Appeal")}`}
        >
          {SUPPORT_EMAIL}
        </a>{" "}
        with the reference above.
      </p>
      <Button variant="outline" className="w-fit" asChild>
        <Link to="/">Back to home</Link>
      </Button>
    </Shell>
  );
}
