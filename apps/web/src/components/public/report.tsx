import { useState, type FormEvent, type ReactNode } from "react";
import { Link, useNavigate } from "@tanstack/react-router";
import { Check, Copy, FileText, Mail, ShieldCheck } from "lucide-react";

import { authErrorMessage } from "@/api/auth";
import { submitPublicReport, type PublicReportResponse } from "@/api/public-reports";
import { PublicFooter, PublicHeader } from "@/components/app-pages";
import { TurnstileWidget } from "@/components/public/turnstile";
import { turnstileSiteKey } from "@/lib/turnstile";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { ABUSE_EMAIL, COPYRIGHT_EMAIL, SUPPORT_RESPONSE_TIME } from "@/lib/support";
import { cn } from "@/lib/utils";

export type ReportType = "copyright" | "abuse";

const fieldLabel = "text-sm font-bold";
const select =
  "h-11 w-full rounded-[12px] border bg-surface px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";

function Field({
  id,
  label,
  hint,
  children,
}: {
  id: string;
  label: string;
  hint?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className={fieldLabel}>
        {label}
      </label>
      {children}
      {hint ? <span className="text-xs text-muted-foreground">{hint}</span> : null}
    </div>
  );
}

function CopyrightForm({
  busy,
  captcha,
  onSubmit,
}: {
  busy: boolean;
  captcha: Captcha;
  onSubmit: (payload: Parameters<typeof submitPublicReport>[0]) => void;
}) {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [relationship, setRelationship] = useState<"rights_holder" | "agent" | "employee">(
    "rights_holder",
  );
  const [work, setWork] = useState("");
  const [locations, setLocations] = useState("");
  const [goodFaith, setGoodFaith] = useState(false);
  const [accurate, setAccurate] = useState(false);
  const [signature, setSignature] = useState("");

  const ready =
    name.trim() &&
    email.includes("@") &&
    work.trim() &&
    locations.trim() &&
    goodFaith &&
    accurate &&
    signature.trim();

  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (!ready) return;
    onSubmit({
      kind: "copyright",
      name,
      email,
      relationship,
      work_description: work,
      locations,
      good_faith: goodFaith,
      accurate_and_authorized: accurate,
      signature,
    });
  };

  return (
    <form className="flex flex-col gap-4" aria-label="Copyright notice" onSubmit={submit}>
      <p className="text-sm text-muted-foreground">
        Fields follow the{" "}
        <Link to="/copyright" className="font-semibold text-accent-ink hover:underline">
          Copyright &amp; Takedown Policy
        </Link>
        . All fields are required.
      </p>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field id="c-name" label="Full legal name">
          <Input
            id="c-name"
            autoComplete="name"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </Field>
        <Field id="c-email" label="Email">
          <Input
            id="c-email"
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </Field>
      </div>
      <Field id="c-rel" label="Relationship to the rights holder">
        <select
          id="c-rel"
          className={select}
          value={relationship}
          onChange={(e) => setRelationship(e.target.value as typeof relationship)}
        >
          <option value="rights_holder">I am the rights holder</option>
          <option value="agent">Authorized agent / representative</option>
          <option value="employee">Employee of the rights holder</option>
        </select>
      </Field>
      <Field id="c-work" label="Description of the copyrighted work">
        <Textarea
          id="c-work"
          className="min-h-[84px]"
          placeholder="Title, type of work, and where the original can be found. A representative list is fine for multiple works."
          value={work}
          onChange={(e) => setWork(e.target.value)}
        />
      </Field>
      <Field
        id="c-loc"
        label="Where is the material on SaveStream?"
        hint="e.g. a savestream.online/recordings link · @handle · tiktok.com/@handle/live"
      >
        <Textarea
          id="c-loc"
          className="min-h-[84px]"
          placeholder="SaveStream recording, account, channel, or source URL — one per line"
          value={locations}
          onChange={(e) => setLocations(e.target.value)}
        />
      </Field>
      <div className="flex flex-col gap-3 rounded-[14px] bg-surface-2 p-4 text-sm">
        <label className="flex items-start gap-2.5">
          <input
            type="checkbox"
            className="mt-0.5 size-4 accent-[var(--primary)]"
            checked={goodFaith}
            onChange={(e) => setGoodFaith(e.target.checked)}
          />
          <span>
            I have a good-faith belief that the disputed use is not authorized by the rights holder,
            its agent, or applicable law.
          </span>
        </label>
        <label className="flex items-start gap-2.5">
          <input
            type="checkbox"
            className="mt-0.5 size-4 accent-[var(--primary)]"
            checked={accurate}
            onChange={(e) => setAccurate(e.target.checked)}
          />
          <span>
            The information in this notice is accurate, and I am the rights holder or authorized to
            act for the rights holder.
          </span>
        </label>
      </div>
      <Field
        id="c-sig"
        label="Electronic signature"
        hint="Typing your full legal name here counts as your electronic signature."
      >
        <Input
          id="c-sig"
          className="italic"
          placeholder="Type your full legal name"
          value={signature}
          onChange={(e) => setSignature(e.target.value)}
        />
      </Field>
      <SubmitArea
        busy={busy}
        ready={Boolean(ready)}
        label="Submit copyright notice"
        captcha={captcha}
      />
    </form>
  );
}

function AbuseForm({
  busy,
  captcha,
  onSubmit,
}: {
  busy: boolean;
  captcha: Captcha;
  onSubmit: (payload: Parameters<typeof submitPublicReport>[0]) => void;
}) {
  const [email, setEmail] = useState("");
  const [target, setTarget] = useState("");
  const [role, setRole] = useState<"self" | "other" | "on_behalf">("self");
  const [description, setDescription] = useState("");
  const ready = email.includes("@") && target.trim() && description.trim();

  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (!ready) return;
    onSubmit({ kind: "abuse", email, target, reporter_role: role, description });
  };

  return (
    <form
      className="flex flex-col gap-4"
      aria-label="Abuse or unauthorized recording report"
      onSubmit={submit}
    >
      <p className="text-sm text-muted-foreground">
        Use this if someone is recording a TikTok LIVE they don’t own or aren’t authorized to record
        (
        <Link to="/acceptable-use" className="font-semibold text-accent-ink hover:underline">
          Acceptable Use Policy
        </Link>
        ).
      </p>
      <Field id="a-email" label="Your email">
        <Input
          id="a-email"
          type="email"
          autoComplete="email"
          placeholder="you@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
      </Field>
      <Field id="a-what" label="What is being recorded?">
        <div className="relative">
          <span className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 font-bold text-muted-foreground">
            @
          </span>
          <Input
            id="a-what"
            className="pl-8"
            placeholder="TikTok handle or LIVE URL"
            value={target}
            onChange={(e) => setTarget(e.target.value)}
          />
        </div>
      </Field>
      <fieldset className="flex flex-col gap-2">
        <legend className={cn(fieldLabel, "mb-2")}>Are you the person in the stream?</legend>
        <div className="flex flex-wrap gap-2">
          {(
            [
              ["self", "Yes, it’s me"],
              ["other", "No"],
              ["on_behalf", "Reporting on behalf of someone"],
            ] as const
          ).map(([value, label]) => (
            <label
              key={value}
              className={cn(
                "inline-flex h-10 cursor-pointer items-center gap-2 rounded-full border px-4 text-sm font-semibold",
                role === value
                  ? "border-primary bg-primary-subtle text-accent-ink"
                  : "bg-surface text-muted-foreground",
              )}
            >
              <input
                type="radio"
                name="reporter-role"
                className="accent-[var(--primary)]"
                checked={role === value}
                onChange={() => setRole(value)}
              />
              {label}
            </label>
          ))}
        </div>
      </fieldset>
      <Field id="a-desc" label="What’s happening?">
        <Textarea
          id="a-desc"
          className="min-h-[110px]"
          placeholder="Describe the problem and when you noticed it."
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />
      </Field>
      <p className="text-xs text-muted-foreground">
        Have screenshots or other evidence? Email them to{" "}
        <a className="font-semibold text-accent-ink" href={`mailto:${ABUSE_EMAIL}`}>
          {ABUSE_EMAIL}
        </a>{" "}
        with the reference you get after sending this report.
      </p>
      <SubmitArea busy={busy} ready={Boolean(ready)} label="Send report" captcha={captcha} />
    </form>
  );
}

type Captcha = {
  token: string | null;
  setToken: (token: string | null) => void;
  resetKey: number;
};

/** Turnstile challenge (only when a site key is configured) and the submit button. */
function SubmitArea({
  busy,
  ready,
  label,
  captcha,
}: {
  busy: boolean;
  ready: boolean;
  label: string;
  captcha: Captcha;
}) {
  const needsToken = Boolean(turnstileSiteKey) && !captcha.token;
  return (
    <div className="flex flex-col gap-3">
      <TurnstileWidget onToken={captcha.setToken} resetKey={captcha.resetKey} />
      <Button type="submit" size="lg" disabled={busy || !ready || needsToken}>
        {busy ? "Sending…" : label}
      </Button>
    </div>
  );
}

function ReportReceived({
  result,
  onAgain,
}: {
  result: PublicReportResponse;
  onAgain: () => void;
}) {
  const [copied, setCopied] = useState(false);
  const copy = () => {
    void navigator.clipboard?.writeText(result.reference).then(() => setCopied(true));
  };
  return (
    <div className="flex flex-col items-center gap-4 px-2 py-8 text-center" role="status">
      <span className="grid size-16 place-items-center rounded-[20px] bg-success-subtle text-success">
        <Check className="size-8" />
      </span>
      <h2 className="text-[26px] font-extrabold tracking-[-.025em]">Report received</h2>
      <p className="max-w-[420px] text-muted-foreground">
        Our team reviews every report and usually replies by email within {SUPPORT_RESPONSE_TIME}.
        Keep this reference for any follow-up.
      </p>
      <div className="flex items-center gap-3 rounded-[14px] bg-surface-2 px-5 py-3.5">
        <span className="text-sm text-muted-foreground">Reference</span>
        <b className="font-mono text-xl">{result.reference}</b>
        <Button size="sm" variant="ghost" onClick={copy}>
          {copied ? <Check className="size-4" /> : <Copy className="size-4" />}
          {copied ? "Copied" : "Copy"}
        </Button>
      </div>
      <div className="flex flex-wrap justify-center gap-2">
        <Button variant="outline" asChild>
          <Link to="/">Back to home</Link>
        </Button>
        <Button variant="ghost" onClick={onAgain}>
          Submit another report
        </Button>
      </div>
    </div>
  );
}

export function PublicReportPage({ type }: { type: ReportType }) {
  const navigate = useNavigate();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<PublicReportResponse | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [resetKey, setResetKey] = useState(0);
  const captcha: Captcha = { token, setToken, resetKey };

  const pick = (next: ReportType) => {
    setError(null);
    void navigate({ to: "/report", search: { type: next }, replace: true });
  };

  const submit = async (payload: Parameters<typeof submitPublicReport>[0]) => {
    setBusy(true);
    setError(null);
    try {
      setResult(await submitPublicReport({ ...payload, turnstile_token: token }));
    } catch (requestError) {
      setError(authErrorMessage(requestError));
      // A Turnstile token is single-use: ask for a fresh challenge.
      setResetKey((key) => key + 1);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <main className="relative pt-[72px]">
        <div aria-hidden className="hero-glow" />
        <div className="relative mx-auto flex max-w-[1100px] flex-wrap items-start gap-12 px-6 pt-16">
          <div className="flex max-w-[360px] flex-[1_1_300px] flex-col gap-4">
            <span className="text-xs font-bold uppercase tracking-[.08em] text-accent-ink">
              Report content
            </span>
            <h1 className="text-[40px] font-extrabold leading-[1.05] tracking-[-.035em] sm:text-[44px]">
              Report a recording or account
            </h1>
            <p className="text-[17px] leading-relaxed text-muted-foreground">
              Tell us about content that infringes your copyright, or a TikTok LIVE being recorded
              without permission. We review every report.
            </p>
            <div className="flex flex-col gap-2.5 rounded-[16px] border bg-surface p-4 text-sm">
              <Link to="/copyright" className="flex items-center gap-2.5 hover:text-accent-ink">
                <FileText className="size-4" />
                Copyright &amp; Takedown Policy
              </Link>
              <Link
                to="/acceptable-use"
                className="flex items-center gap-2.5 hover:text-accent-ink"
              >
                <ShieldCheck className="size-4" />
                Acceptable Use Policy
              </Link>
              <span className="flex items-center gap-2.5 text-muted-foreground">
                <Mail className="size-4" />
                <span>
                  Prefer email?{" "}
                  <a className="text-accent-ink" href={`mailto:${COPYRIGHT_EMAIL}`}>
                    copyright@
                  </a>{" "}
                  ·{" "}
                  <a className="text-accent-ink" href={`mailto:${ABUSE_EMAIL}`}>
                    abuse@
                  </a>
                </span>
              </span>
            </div>
          </div>

          <section
            className="flex min-w-0 flex-[999_1_520px] flex-col gap-5 rounded-[20px] border bg-surface p-6 shadow-card sm:p-8"
            aria-label="Report form"
          >
            {result ? (
              <ReportReceived result={result} onAgain={() => setResult(null)} />
            ) : (
              <>
                <div role="tablist" aria-label="Report type" className="flex gap-1 border-b">
                  {(
                    [
                      ["copyright", "Copyright notice"],
                      ["abuse", "Abuse / unauthorized recording"],
                    ] as const
                  ).map(([value, label]) => (
                    <button
                      key={value}
                      type="button"
                      role="tab"
                      aria-selected={type === value}
                      onClick={() => pick(value)}
                      className={cn(
                        "-mb-px h-11 border-b-2 border-transparent px-3 text-sm font-bold text-muted-foreground",
                        type === value && "border-primary text-foreground",
                      )}
                    >
                      {label}
                    </button>
                  ))}
                </div>
                {error ? (
                  <p
                    role="alert"
                    className="rounded-[12px] border border-destructive/30 bg-recording-subtle px-4 py-3 text-sm text-destructive"
                  >
                    {error}
                  </p>
                ) : null}
                {type === "copyright" ? (
                  <CopyrightForm
                    busy={busy}
                    captcha={captcha}
                    onSubmit={(payload) => void submit(payload)}
                  />
                ) : (
                  <AbuseForm
                    busy={busy}
                    captcha={captcha}
                    onSubmit={(payload) => void submit(payload)}
                  />
                )}
              </>
            )}
          </section>
        </div>
      </main>
      <PublicFooter />
    </div>
  );
}
