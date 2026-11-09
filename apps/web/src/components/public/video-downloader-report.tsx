import { useState, type FormEvent, type ReactNode } from "react";
import { Link } from "@tanstack/react-router";
import { Check, Copy } from "lucide-react";

import { authErrorMessage } from "@/api/auth";
import { ApiError } from "@/api/errors";
import { videoDownloaderApi, type VideoDownloaderReportRequest } from "@/api/video-downloader";
import { PublicFrame } from "@/components/public/guides-pages";
import { TurnstileWidget } from "@/components/public/turnstile";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { turnstileSiteKey } from "@/lib/turnstile";
import { REPORT_RESPONSE_TIME, looksLikeTikTokLink } from "@/lib/video-downloader";

const select =
  "h-11 w-full rounded-[12px] border bg-surface px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";

/** The design's reasons, mapped to the API's reason codes. */
const REASONS = [
  ["mine", "It’s my video and I don’t want it downloadable here", "copyright"],
  ["copyright", "Copyright infringement — I own the rights", "copyright"],
  ["consent", "I appear in the video without my consent", "privacy"],
  ["privacy", "Privacy or safety concern", "privacy"],
  ["other", "Something else", "other"],
] as const satisfies readonly (readonly [string, string, VideoDownloaderReportRequest["reason"]])[];

const RELATIONSHIPS = [
  ["creator", "I’m the creator of the video"],
  ["rights_holder", "I own the rights to the content"],
  ["agent", "Authorized agent / representative"],
  ["other", "Other (for example, I appear in the video)"],
] as const satisfies readonly (readonly [VideoDownloaderReportRequest["relationship"], string])[];

function Field({
  id,
  label,
  hint,
  children,
}: {
  id: string;
  label: ReactNode;
  hint?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className="text-sm font-bold">
        {label}
      </label>
      {children}
      {hint ? <span className="text-xs text-muted-foreground">{hint}</span> : null}
    </div>
  );
}

function reportErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    switch (error.code) {
      case "INVALID_LINK":
        return "That doesn’t look like a TikTok video link. Copy it from the video’s Share menu.";
      case "CAPTCHA_FAILED":
      case "CAPTCHA_REQUIRED":
        return "The security check failed. Please complete it again and resend.";
      case "RATE_LIMITED":
        return "Too many requests. Please wait a little and try again.";
      case "VALIDATION_ERROR":
        return error.serverMessage ?? "Check the information you entered and try again.";
    }
  }
  return authErrorMessage(error);
}

function RequestReceived({ reference }: { reference: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="flex flex-col items-center gap-3.5 px-2 py-7 text-center" role="status">
      <span className="grid size-16 place-items-center rounded-[20px] bg-success-subtle text-success">
        <Check className="size-8" />
      </span>
      <h2 className="text-[30px] font-extrabold tracking-[-.025em]">Request received</h2>
      <p className="m-0 max-w-[420px] text-muted-foreground">
        Reference <b className="font-mono text-foreground">{reference}</b>. We’ve blocked this link
        in the downloader while we review it. We usually reply {REPORT_RESPONSE_TIME}.
      </p>
      <div className="flex flex-wrap justify-center gap-2">
        <Button
          variant="ghost"
          onClick={() => {
            void navigator.clipboard?.writeText(reference).then(() => setCopied(true));
          }}
        >
          {copied ? <Check className="size-4" /> : <Copy className="size-4" />}
          {copied ? "Copied" : "Copy reference"}
        </Button>
        <Button variant="outline" asChild>
          <Link to="/video-downloader">Back to the downloader</Link>
        </Button>
      </div>
    </div>
  );
}

export function VideoDownloaderReportPage() {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [videoUrl, setVideoUrl] = useState("");
  const [reasonKey, setReasonKey] = useState<(typeof REASONS)[number][0]>("mine");
  const [relationship, setRelationship] =
    useState<VideoDownloaderReportRequest["relationship"]>("creator");
  const [details, setDetails] = useState("");
  const [goodFaith, setGoodFaith] = useState(false);
  const [accurate, setAccurate] = useState(false);
  const [signature, setSignature] = useState("");
  const [token, setToken] = useState<string | null>(null);
  const [resetKey, setResetKey] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [reference, setReference] = useState<string | null>(null);

  const linkOk = looksLikeTikTokLink(videoUrl);
  const ready =
    name.trim() && email.includes("@") && linkOk && goodFaith && accurate && signature.trim();
  const needsToken = Boolean(turnstileSiteKey) && !token;

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (!ready || busy || needsToken) return;
    const reason = REASONS.find(([key]) => key === reasonKey) ?? REASONS[0];
    setBusy(true);
    setError(null);
    try {
      const result = await videoDownloaderApi.report({
        video_url: videoUrl.trim(),
        reporter_name: name.trim(),
        reporter_email: email.trim(),
        relationship,
        reason: reason[2],
        // The API has no fields for the chosen wording or the signature: keep them in details.
        details: [
          details.trim(),
          `Reason: ${reason[1]}`,
          `Electronic signature: ${signature.trim()}`,
        ]
          .filter(Boolean)
          .join("\n\n"),
        good_faith: true,
        ...(token ? { turnstile_token: token } : {}),
      });
      setReference(result.reference);
    } catch (requestError) {
      setError(reportErrorMessage(requestError));
      // A Turnstile token is single-use: ask for a fresh challenge.
      setToken(null);
      setResetKey((key) => key + 1);
    } finally {
      setBusy(false);
    }
  };

  return (
    <PublicFrame>
      <main className="relative mx-auto flex max-w-[1000px] flex-wrap items-start gap-10 px-4 pt-14 sm:px-6">
        <div className="flex max-w-[340px] flex-[1_1_280px] flex-col gap-3.5">
          <Link
            to="/video-downloader"
            className="text-sm font-bold text-accent-ink hover:underline"
          >
            ← Back to the video downloader
          </Link>
          <span className="text-[13px] font-bold uppercase tracking-[.08em] text-accent-ink">
            Video downloader
          </span>
          <h1 className="text-[34px] font-extrabold leading-[1.08] tracking-[-.03em]">
            Report a video or request copyright removal
          </h1>
          <p className="m-0 leading-relaxed text-muted-foreground">
            Are you the creator or rights holder? Tell us which video should not be available
            through our downloader. When a request is valid, we block that link in the tool.
          </p>
          <p className="m-0 text-xs leading-relaxed text-muted-foreground">
            Full process:{" "}
            <Link to="/copyright" className="font-semibold text-accent-ink hover:underline">
              Copyright &amp; Takedown Policy
            </Link>
            . False or misleading notices may have legal consequences.
          </p>
        </div>

        <section
          className="flex min-w-0 flex-[999_1_480px] flex-col gap-[18px] rounded-[20px] border bg-surface p-6 shadow-card sm:p-8"
          aria-label="Report form"
        >
          {reference ? (
            <RequestReceived reference={reference} />
          ) : (
            <form className="flex flex-col gap-[18px]" onSubmit={(e) => void submit(e)}>
              {error ? (
                <p
                  role="alert"
                  className="m-0 rounded-[12px] border border-destructive/30 bg-recording-subtle px-4 py-3 text-sm text-destructive"
                >
                  {error}
                </p>
              ) : null}
              <div className="grid gap-4 sm:grid-cols-2">
                <Field id="r-n" label="Your name">
                  <Input
                    id="r-n"
                    autoComplete="name"
                    placeholder="Full legal name"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                  />
                </Field>
                <Field id="r-e" label="Email">
                  <Input
                    id="r-e"
                    type="email"
                    autoComplete="email"
                    placeholder="you@example.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                  />
                </Field>
              </div>
              <Field
                id="r-l"
                label="Video link"
                hint="One link per request. Add more in the details box."
              >
                <Input
                  id="r-l"
                  type="url"
                  placeholder="https://www.tiktok.com/@name/video/…"
                  value={videoUrl}
                  aria-invalid={videoUrl.trim() !== "" && !linkOk}
                  onChange={(e) => setVideoUrl(e.target.value)}
                />
              </Field>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field id="r-r" label="Reason">
                  <select
                    id="r-r"
                    className={select}
                    value={reasonKey}
                    onChange={(e) => setReasonKey(e.target.value as typeof reasonKey)}
                  >
                    {REASONS.map(([key, label]) => (
                      <option key={key} value={key}>
                        {label}
                      </option>
                    ))}
                  </select>
                </Field>
                <Field id="r-rel" label="You are">
                  <select
                    id="r-rel"
                    className={select}
                    value={relationship}
                    onChange={(e) => setRelationship(e.target.value as typeof relationship)}
                  >
                    {RELATIONSHIPS.map(([value, label]) => (
                      <option key={value} value={value}>
                        {label}
                      </option>
                    ))}
                  </select>
                </Field>
              </div>
              <Field
                id="r-d"
                label={
                  <>
                    Details <span className="font-medium text-muted-foreground">(optional)</span>
                  </>
                }
              >
                <Textarea
                  id="r-d"
                  className="min-h-[100px]"
                  maxLength={1500}
                  placeholder="Describe the work or the problem."
                  value={details}
                  onChange={(e) => setDetails(e.target.value)}
                />
              </Field>
              <label className="flex items-start gap-2.5 text-sm">
                <input
                  type="checkbox"
                  className="mt-0.5 size-4 accent-[var(--primary)]"
                  checked={goodFaith}
                  onChange={(e) => setGoodFaith(e.target.checked)}
                />
                <span>
                  I have a good-faith belief that this use is not authorized by the rights holder,
                  its agent, or the law.
                </span>
              </label>
              <label className="flex items-start gap-2.5 text-sm">
                <input
                  type="checkbox"
                  className="mt-0.5 size-4 accent-[var(--primary)]"
                  checked={accurate}
                  onChange={(e) => setAccurate(e.target.checked)}
                />
                <span>
                  The information in this request is accurate, and I am the rights holder or
                  authorized to act for them.
                </span>
              </label>
              <Field id="r-s" label="Electronic signature">
                <Input
                  id="r-s"
                  className="italic"
                  placeholder="Type your full legal name"
                  value={signature}
                  onChange={(e) => setSignature(e.target.value)}
                />
              </Field>
              <TurnstileWidget onToken={setToken} resetKey={resetKey} />
              <Button
                type="submit"
                size="lg"
                className="w-full"
                disabled={!ready || busy || needsToken}
              >
                {busy ? "Sending…" : "Send request"}
              </Button>
            </form>
          )}
        </section>
      </main>
    </PublicFrame>
  );
}
