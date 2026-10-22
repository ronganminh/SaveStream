import { useState, type FormEvent } from "react";
import { Link } from "@tanstack/react-router";
import { Check, Mail, Smartphone, Trash2 } from "lucide-react";

import { authApi, authErrorMessage } from "@/api/auth";
import { PublicFooter, PublicHeader } from "@/components/app-pages";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PRIVACY_EMAIL } from "@/lib/support";

// Account deletion page required by Google Play (Data safety "delete
// account" URL): works without signing in, explains what is deleted and
// kept, and confirms by a one-time emailed link.

function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <main className="relative pt-[72px]">
        <div className="relative mx-auto flex max-w-[760px] flex-col gap-8 px-6 py-16">
          {children}
        </div>
      </main>
      <PublicFooter />
    </div>
  );
}

const DELETED = [
  "Your account, sign-in methods (password, Google, Apple) and active sessions",
  "Your channels, recordings and their video files",
  "Notifications, preferences and devices registered for push",
  "Partner Program applications sent with your email",
];
const KEPT = [
  "Purchase and refund records, kept for accounting and tax law",
  "Security logs without your IP address or browser details",
  "Proof that you accepted our Terms, as the law requires",
];

export function DeleteAccountPage() {
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (!/^\S+@\S+\.\S+$/.test(email.trim())) {
      setError("Enter the email address of your SaveStream account.");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await authApi.requestAccountDeletion(email.trim());
      setSent(true);
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Shell>
      <div className="flex flex-col gap-3">
        <span className="text-xs font-bold uppercase tracking-[.08em] text-accent-ink">
          Account
        </span>
        <h1 className="text-[40px] font-extrabold leading-[1.05] tracking-[-.035em]">
          Delete your SaveStream account
        </h1>
        <p className="text-[17px] leading-relaxed text-muted-foreground">
          You can delete your account and personal data at any time, from the app or from this page.
          Deletion starts as soon as you confirm and can’t be undone.
        </p>
      </div>

      <section className="grid gap-3 sm:grid-cols-2" aria-label="Ways to delete">
        <div className="flex flex-col gap-2 rounded-[16px] border bg-surface p-5">
          <Smartphone className="size-5 text-accent-ink" aria-hidden="true" />
          <h2 className="font-extrabold">In the app</h2>
          <p className="text-sm text-muted-foreground">
            Open SaveStream, go to Settings → Account → Delete account, then confirm.
          </p>
        </div>
        <div className="flex flex-col gap-2 rounded-[16px] border bg-surface p-5">
          <Trash2 className="size-5 text-accent-ink" aria-hidden="true" />
          <h2 className="font-extrabold">On the web</h2>
          <p className="text-sm text-muted-foreground">
            Signed in? Go to{" "}
            <Link to="/settings/account" className="font-semibold text-accent-ink hover:underline">
              Settings → Account
            </Link>
            . Otherwise, ask for a confirmation link below.
          </p>
        </div>
      </section>

      <section
        className="flex flex-col gap-4 rounded-[20px] border bg-surface p-6"
        aria-labelledby="request"
      >
        <h2 id="request" className="text-xl font-extrabold">
          Get a deletion link by email
        </h2>
        {sent ? (
          <p
            role="status"
            className="flex items-start gap-2 rounded-xl bg-success-subtle p-3 text-sm text-success"
          >
            <Check className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
            If an account uses this address, we sent a link to confirm the deletion. It works for 1
            hour. Check your spam folder if you don’t see it.
          </p>
        ) : (
          <form
            className="flex flex-col gap-3 sm:flex-row sm:items-end"
            onSubmit={submit}
            noValidate
          >
            <div className="flex flex-1 flex-col gap-1.5">
              <label htmlFor="delete-email" className="text-sm font-bold">
                Account email
              </label>
              <Input
                id="delete-email"
                type="email"
                autoComplete="email"
                placeholder="you@example.com"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                aria-invalid={error ? true : undefined}
                aria-describedby={error ? "delete-email-error" : undefined}
              />
            </div>
            <Button type="submit" disabled={busy}>
              <Mail aria-hidden="true" />
              {busy ? "Sending…" : "Send link"}
            </Button>
          </form>
        )}
        {error ? (
          <p id="delete-email-error" role="alert" className="text-sm text-destructive">
            {error}
          </p>
        ) : null}
      </section>

      <section className="grid gap-6 sm:grid-cols-2">
        <div className="flex flex-col gap-2">
          <h2 className="font-extrabold">What we delete</h2>
          <ul className="list-disc space-y-1.5 pl-5 text-sm text-muted-foreground">
            {DELETED.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </div>
        <div className="flex flex-col gap-2">
          <h2 className="font-extrabold">What we keep</h2>
          <ul className="list-disc space-y-1.5 pl-5 text-sm text-muted-foreground">
            {KEPT.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </div>
      </section>
      <p className="text-sm text-muted-foreground">
        Unused recording time is lost when the account is deleted. Questions? Email{" "}
        <a href={`mailto:${PRIVACY_EMAIL}`} className="font-semibold text-accent-ink">
          {PRIVACY_EMAIL}
        </a>
        . See also our{" "}
        <Link to="/privacy" className="font-semibold text-accent-ink hover:underline">
          Privacy Policy
        </Link>
        .
      </p>
    </Shell>
  );
}

export function DeleteAccountConfirmPage({ token }: { token: string }) {
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const confirm = async () => {
    setBusy(true);
    setError(null);
    try {
      await authApi.confirmAccountDeletion(token);
      setDone(true);
    } catch (requestError) {
      setError(authErrorMessage(requestError));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Shell>
      <h1 className="text-[36px] font-extrabold leading-[1.05] tracking-[-.035em]">
        {done ? "Your account is being deleted" : "Delete your account permanently?"}
      </h1>
      {done ? (
        <p role="status" className="text-[17px] leading-relaxed text-muted-foreground">
          You’ve been signed out everywhere. Your recordings, channels and personal data are being
          removed, and we sent a confirmation email.
        </p>
      ) : !token ? (
        <p role="alert" className="text-destructive">
          This link is incomplete.{" "}
          <Link to="/delete-account" className="font-semibold underline">
            Request a new deletion link
          </Link>
          .
        </p>
      ) : (
        <>
          <p className="text-[17px] leading-relaxed text-muted-foreground">
            This signs you out on every device and deletes your recordings, channels and personal
            data. Unused recording time is lost. This can’t be undone.
          </p>
          <div className="flex flex-wrap gap-3">
            <Button variant="destructive" disabled={busy} onClick={() => void confirm()}>
              <Trash2 aria-hidden="true" />
              {busy ? "Deleting…" : "Delete my account"}
            </Button>
            <Button asChild variant="outline">
              <Link to="/">Keep my account</Link>
            </Button>
          </div>
          {error ? (
            <p role="alert" className="text-sm text-destructive">
              {error}{" "}
              <Link to="/delete-account" className="font-semibold underline">
                Request a new link
              </Link>
            </p>
          ) : null}
        </>
      )}
    </Shell>
  );
}
