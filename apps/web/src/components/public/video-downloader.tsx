import { useEffect, useRef, useState, type FormEvent, type ReactNode } from "react";
import { Link } from "@tanstack/react-router";
import {
  AlertCircle,
  Ban,
  ClipboardPaste,
  Clock3,
  Download,
  Hand,
  Link2,
  Lock,
  Play,
  RotateCw,
  ShieldCheck,
} from "lucide-react";

import { ApiError } from "@/api/errors";
import { videoDownloaderApi } from "@/api/video-downloader";
import { useAuth } from "@/auth/auth-context";
import { PublicFrame } from "@/components/public/guides-pages";
import { TurnstileWidget } from "@/components/public/turnstile";
import { Button } from "@/components/ui/button";
import { usePublicPricingData } from "@/hooks/use-domain-data";
import { useVideoDownloaderStatus } from "@/hooks/use-video-downloader";
import { apiBaseUrl } from "@/lib/app-config";
import { helpVariables } from "@/lib/help-content";
import { turnstileSiteKey } from "@/lib/turnstile";
import { cn } from "@/lib/utils";
import {
  DOWNLOADER_NOTICE,
  DOWNLOADS_ALLOWED_LINE,
  FILE_RETENTION_ANSWER,
  INVALID_LINK_STATE,
  LINK_EXPIRED_STATE,
  TOOL_OFF_BODY,
  TOOL_OFF_TITLE,
  apiAssetUrl,
  downloadLinkExpired,
  downloaderErrorState,
  formatVideoDuration,
  looksLikeTikTokLink,
  needsTurnstile,
  pickPublicDownload,
  publicDownloadLabel,
  retryLabel,
  type DownloaderErrorState,
  type VideoDownloaderFile,
  type VideoDownloaderResult,
} from "@/lib/video-downloader";

const eyebrow = "text-[13px] font-bold uppercase tracking-[.08em] text-accent-ink";
const card = "rounded-[20px] border bg-surface shadow-card";

export const REPORT_PATH = "/video-downloader/report";

// --- Shared pieces (also used by /my-videos) ------------------------------------------

const toneStyles: Record<DownloaderErrorState["tone"], { banner: string; tile: string }> = {
  err: {
    banner: "border-destructive/30 bg-recording-subtle",
    tile: "bg-destructive/10 text-destructive",
  },
  warn: { banner: "border-warning/40 bg-warning-subtle", tile: "bg-warning/15 text-warning" },
  info: { banner: "border-info/30 bg-info-subtle", tile: "bg-info/15 text-info" },
};

function errorIcon(kind: DownloaderErrorState["kind"]) {
  switch (kind) {
    case "private":
    case "blocked":
    case "not_your_channel":
      return Lock;
    case "disabled":
      return Hand;
    case "rate":
    case "expired":
      return Clock3;
    case "tool_off":
      return Ban;
    case "captcha":
    case "no_verified_channel":
      return ShieldCheck;
    default:
      return AlertCircle;
  }
}

/** Seconds left on a "Try again in m:ss" countdown. */
export function useCountdown(seconds: number | null): number | null {
  const [until, setUntil] = useState<number | null>(null);
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    setUntil(seconds ? Date.now() + seconds * 1000 : null);
    setNow(Date.now());
  }, [seconds]);
  useEffect(() => {
    if (!until) return;
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [until]);
  if (!until) return null;
  return Math.max(0, Math.ceil((until - now) / 1000));
}

export function DownloaderErrorBanner({
  error,
  onRetry,
  onReset,
  action,
}: {
  error: DownloaderErrorState;
  onRetry?: () => void;
  onReset?: () => void;
  action?: ReactNode;
}) {
  const remaining = useCountdown(error.kind === "rate" ? error.retryAfterSeconds : null);
  const Icon = errorIcon(error.kind);
  const tone = toneStyles[error.tone];
  return (
    <div
      id="vd-err"
      role="alert"
      className={cn("flex flex-wrap items-start gap-3.5 rounded-[16px] border p-4", tone.banner)}
    >
      <span className={cn("grid size-10 shrink-0 place-items-center rounded-[12px]", tone.tile)}>
        <Icon className="size-5" />
      </span>
      <div className="flex min-w-[220px] flex-1 flex-col gap-1">
        <b>{error.title}</b>
        <span className="text-sm leading-relaxed">{error.body}</span>
        {error.meta ? (
          <span className="font-mono text-xs text-muted-foreground">{error.meta}</span>
        ) : null}
      </div>
      <div className="flex flex-wrap gap-2">
        {action}
        {error.retry && onRetry ? (
          <Button
            type="button"
            size="sm"
            variant="outline"
            onClick={onRetry}
            disabled={Boolean(remaining && remaining > 0)}
          >
            <RotateCw className="size-3.5" />
            {retryLabel(remaining)}
          </Button>
        ) : null}
        {onReset ? (
          <Button type="button" size="sm" variant="ghost" onClick={onReset}>
            Try another link
          </Button>
        ) : null}
      </div>
    </div>
  );
}

export function DownloaderLoading() {
  return (
    <section
      className={cn(card, "flex flex-wrap items-center gap-7 p-6 sm:p-7")}
      role="status"
      aria-live="polite"
      aria-label="Fetching video"
    >
      <div className="h-[320px] w-[180px] flex-none animate-pulse rounded-[18px] bg-surface-2" />
      <div className="flex min-w-0 flex-[1_1_300px] flex-col gap-3.5">
        <div className="flex items-center gap-2">
          <span
            aria-hidden
            className="size-[22px] animate-spin rounded-full border-[3px] border-primary-subtle border-t-primary"
          />
          <b>Fetching video…</b>
        </div>
        <div className="h-[18px] w-2/5 animate-pulse rounded-md bg-surface-2" />
        <div className="h-3.5 w-[85%] animate-pulse rounded-md bg-surface-2" />
        <div className="h-3.5 w-[70%] animate-pulse rounded-md bg-surface-2" />
        <div className="mt-2 h-[52px] w-[220px] animate-pulse rounded-[12px] bg-surface-2" />
        <span className="text-xs text-muted-foreground">This usually takes a few seconds.</span>
      </div>
    </section>
  );
}

function initials(name: string) {
  const letters = name.replace(/^@/, "").replace(/[^a-z0-9]/gi, "");
  return (letters.slice(0, 2) || "TT").toUpperCase();
}

function postedDate(value: string | null | undefined) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

/** Cover, creator, caption and facts; `actions` holds the download buttons. */
export function DownloaderResultCard({
  result,
  actions,
  footer,
  subtitle = DOWNLOADS_ALLOWED_LINE,
}: {
  result: VideoDownloaderResult;
  actions: ReactNode;
  footer?: ReactNode;
  subtitle?: string;
}) {
  const { video } = result;
  const cover = apiAssetUrl(apiBaseUrl, video.cover_url);
  const [coverFailed, setCoverFailed] = useState(false);
  const duration = formatVideoDuration(video.duration_seconds);
  const posted = postedDate(video.posted_at);
  const handle = `@${video.username.replace(/^@/, "")}`;
  return (
    <section
      className={cn(card, "flex flex-wrap items-start gap-7 p-6 sm:p-7")}
      aria-label="Video ready"
    >
      <div className="relative mx-auto grid h-[320px] w-[180px] flex-none place-items-center overflow-hidden rounded-[18px] bg-gradient-to-br from-thumbnail-one to-thumbnail-three sm:mx-0">
        {cover && !coverFailed ? (
          <img
            src={cover}
            alt={`Cover of the video by ${handle}`}
            className="absolute inset-0 size-full object-cover"
            onError={() => setCoverFailed(true)}
          />
        ) : null}
        <span className="relative grid size-14 place-items-center rounded-full bg-white/90 text-[#15122B]">
          <Play className="size-6" />
        </span>
        {duration ? (
          <span className="absolute bottom-2.5 right-2.5 rounded-md bg-black/70 px-1.5 py-0.5 font-mono text-xs font-semibold text-white">
            {duration}
          </span>
        ) : null}
      </div>
      <div className="flex min-w-0 flex-[1_1_300px] flex-col gap-4">
        <div className="flex items-center gap-2.5">
          <span className="grid size-10 shrink-0 place-items-center rounded-full bg-gradient-to-br from-avatar-three to-avatar-three-end text-sm font-semibold text-avatar-foreground">
            {initials(video.username)}
          </span>
          <div className="flex min-w-0 flex-col">
            <b className="truncate">{handle}</b>
            <span className="text-xs text-muted-foreground">{subtitle}</span>
          </div>
        </div>
        {video.caption ? (
          <p className="m-0 line-clamp-4 text-base leading-relaxed">{video.caption}</p>
        ) : null}
        {duration || posted ? (
          <dl className="grid w-fit grid-cols-[auto_1fr] gap-x-6 gap-y-1.5 text-sm">
            {duration ? (
              <>
                <dt className="text-muted-foreground">Duration</dt>
                <dd className="font-mono">{duration}</dd>
              </>
            ) : null}
            {posted ? (
              <>
                <dt className="text-muted-foreground">Posted</dt>
                <dd>{posted}</dd>
              </>
            ) : null}
          </dl>
        ) : null}
        <div className="flex flex-wrap gap-2.5">{actions}</div>
        {footer}
      </div>
    </section>
  );
}

export function ToolOffNotice({ homeTo = "/" }: { homeTo?: "/" | "/overview" }) {
  return (
    <section
      className={cn(card, "flex flex-col items-center gap-3 p-8 text-center")}
      role="status"
      aria-labelledby="vd-off"
    >
      <span className="grid size-14 place-items-center rounded-[18px] bg-surface-2 text-muted-foreground">
        <Ban className="size-7" />
      </span>
      <h2 id="vd-off" className="text-[22px] font-extrabold tracking-[-.02em]">
        {TOOL_OFF_TITLE}
      </h2>
      <p className="m-0 max-w-[460px] text-muted-foreground">{TOOL_OFF_BODY}</p>
      <Button variant="outline" asChild>
        <Link to={homeTo}>{homeTo === "/" ? "Back to home" : "Back to overview"}</Link>
      </Button>
    </section>
  );
}

// --- Public page -------------------------------------------------------------------------

type Phase =
  | { kind: "idle" }
  | { kind: "loading" }
  | { kind: "error"; error: DownloaderErrorState }
  | { kind: "result"; result: VideoDownloaderResult; receivedAt: number };

function PublicDownloadButton({
  file,
  receivedAt,
  expiresIn,
  onExpired,
}: {
  file: VideoDownloaderFile;
  receivedAt: number;
  expiresIn: number;
  onExpired: () => void;
}) {
  const href = apiAssetUrl(apiBaseUrl, file.download_url) ?? undefined;
  return (
    <Button size="lg" asChild>
      {/* Direct link: the API sends the file as an attachment. */}
      <a
        href={href}
        rel="nofollow noopener"
        download
        onClick={(event) => {
          if (downloadLinkExpired(receivedAt, expiresIn, Date.now())) {
            event.preventDefault();
            onExpired();
          }
        }}
      >
        <Download className="size-[18px]" />
        {publicDownloadLabel(file)}
      </a>
    </Button>
  );
}

export function VideoDownloaderPage({ expired = false }: { expired?: boolean }) {
  const { enabled, loading } = useVideoDownloaderStatus();
  const [url, setUrl] = useState("");
  const [phase, setPhase] = useState<Phase>(
    expired ? { kind: "error", error: LINK_EXPIRED_STATE } : { kind: "idle" },
  );
  const [captchaRequired, setCaptchaRequired] = useState(false);
  const [token, setToken] = useState<string | null>(null);
  const [resetKey, setResetKey] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  const busy = phase.kind === "loading";
  const needsToken = captchaRequired && Boolean(turnstileSiteKey) && !token;

  const run = async (raw: string) => {
    const link = raw.trim();
    if (!looksLikeTikTokLink(link)) {
      setPhase({ kind: "error", error: INVALID_LINK_STATE });
      return;
    }
    const usedToken = captchaRequired ? token : null;
    setPhase({ kind: "loading" });
    try {
      const result = await videoDownloaderApi.resolve(link, usedToken);
      setCaptchaRequired(Boolean(result.turnstile_required_next));
      setPhase({ kind: "result", result, receivedAt: Date.now() });
    } catch (requestError) {
      const apiError = requestError instanceof ApiError ? requestError : null;
      const error = downloaderErrorState(apiError ?? {});
      if (apiError && needsTurnstile(apiError)) {
        setCaptchaRequired(true);
        // Without a site key the challenge can't be shown: fall back to the generic state.
        setPhase({
          kind: "error",
          error: turnstileSiteKey ? error : downloaderErrorState({ ...apiError, code: "" }),
        });
      } else {
        setPhase({ kind: "error", error });
      }
    } finally {
      if (usedToken) {
        // A Turnstile token is single-use.
        setToken(null);
        setResetKey((key) => key + 1);
      }
    }
  };

  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (busy || needsToken) return;
    void run(url);
  };

  const reset = () => {
    setUrl("");
    setPhase({ kind: "idle" });
    inputRef.current?.focus();
  };

  const paste = async () => {
    try {
      const text = await navigator.clipboard?.readText();
      if (text) setUrl(text.trim());
    } catch {
      // Clipboard access denied: the visitor can paste by hand.
    }
    inputRef.current?.focus();
  };

  const invalid = phase.kind === "error" && phase.error.kind === "invalid";
  const showInfo = phase.kind !== "loading" && phase.kind !== "result";

  return (
    <PublicFrame>
      <div className="relative">
        <div aria-hidden className="hero-glow" />
        <main className="relative mx-auto flex max-w-[980px] flex-col gap-7 px-4 pt-16 sm:px-6">
          <header className="flex flex-col items-center gap-3 text-center">
            <span className={eyebrow}>Free tool · no sign-up</span>
            <h1 className="text-[clamp(34px,6vw,52px)] font-extrabold leading-[1.05] tracking-[-.035em] text-balance">
              Download a TikTok video
            </h1>
            <p className="m-0 max-w-[560px] text-lg leading-relaxed text-muted-foreground">
              Paste a link to a public video and save it as MP4.
            </p>
          </header>

          {loading ? (
            <div className={cn(card, "h-[82px] animate-pulse")} aria-busy="true" />
          ) : !enabled ? (
            <ToolOffNotice />
          ) : (
            <>
              <form
                className={cn(
                  card,
                  "flex flex-wrap gap-2.5 p-2.5 shadow-[0_24px_50px_-24px_var(--glow)]",
                  invalid && "border-destructive",
                )}
                aria-label="Video link"
                noValidate
                onSubmit={submit}
              >
                <label htmlFor="vd-url" className="relative min-w-0 flex-[999_1_320px]">
                  <span className="sr-only">Video link</span>
                  <Link2
                    aria-hidden
                    className="pointer-events-none absolute left-4 top-1/2 size-5 -translate-y-1/2 text-muted-foreground"
                  />
                  <input
                    id="vd-url"
                    ref={inputRef}
                    type="url"
                    inputMode="url"
                    autoComplete="off"
                    placeholder="Paste a video link"
                    value={url}
                    onChange={(event) => setUrl(event.target.value)}
                    aria-invalid={invalid}
                    aria-describedby="vd-note vd-err"
                    className="h-[60px] w-full rounded-[14px] bg-transparent pl-[50px] pr-[104px] text-[17px] outline-none placeholder:text-muted-foreground focus-visible:ring-2 focus-visible:ring-ring"
                  />
                  <Button
                    type="button"
                    size="sm"
                    variant="ghost"
                    className="absolute right-2 top-1/2 -translate-y-1/2"
                    onClick={() => void paste()}
                  >
                    <ClipboardPaste className="size-4" />
                    Paste
                  </Button>
                </label>
                <Button
                  type="submit"
                  size="lg"
                  className="h-[60px] flex-[1_1_160px] text-[17px]"
                  disabled={busy || needsToken}
                >
                  <Download className="size-5" />
                  {busy ? "Fetching…" : "Download"}
                </Button>
              </form>

              {captchaRequired && turnstileSiteKey ? (
                <div className="flex flex-col items-center gap-2" aria-label="Security check">
                  <span className="text-sm text-muted-foreground">
                    Quick check before your next download.
                  </span>
                  <TurnstileWidget onToken={setToken} resetKey={resetKey} />
                </div>
              ) : null}

              <p
                id="vd-note"
                className="m-0 flex items-center justify-center gap-2 text-center text-sm text-muted-foreground"
              >
                <ShieldCheck aria-hidden className="size-4 shrink-0" />
                <span>{DOWNLOADER_NOTICE}</span>
              </p>

              {phase.kind === "error" ? (
                <DownloaderErrorBanner
                  error={phase.error}
                  onRetry={() => void run(url)}
                  onReset={reset}
                />
              ) : null}

              {phase.kind === "loading" ? <DownloaderLoading /> : null}

              {phase.kind === "result" ? (
                <PublicResult
                  result={phase.result}
                  receivedAt={phase.receivedAt}
                  onExpired={() => setPhase({ kind: "error", error: LINK_EXPIRED_STATE })}
                  onReset={reset}
                />
              ) : null}
            </>
          )}

          {showInfo ? <DownloaderInfo /> : null}
        </main>
      </div>
    </PublicFrame>
  );
}

function PublicResult({
  result,
  receivedAt,
  onExpired,
  onReset,
}: {
  result: VideoDownloaderResult;
  receivedAt: number;
  onExpired: () => void;
  onReset: () => void;
}) {
  const file = pickPublicDownload(result.files);
  return (
    <DownloaderResultCard
      result={result}
      actions={
        file ? (
          <PublicDownloadButton
            file={file}
            receivedAt={receivedAt}
            expiresIn={result.expires_in_seconds}
            onExpired={onExpired}
          />
        ) : (
          <p className="m-0 text-sm text-muted-foreground">
            No downloadable file is available for this video.
          </p>
        )
      }
      footer={
        <>
          <Button type="button" variant="ghost" className="self-start" onClick={onReset}>
            <RotateCw className="size-4" />
            Download another
          </Button>
          <p className="m-0 text-xs leading-relaxed text-muted-foreground">
            For personal use only. Don’t re-upload or share other people’s videos without their
            permission. Is this your video and you want it removed?{" "}
            <Link to={REPORT_PATH} className="font-semibold text-accent-ink hover:underline">
              Report it
            </Link>
            .
          </p>
        </>
      }
    />
  );
}

function DownloaderInfo() {
  const { status } = useAuth();
  const { query } = usePublicPricingData();
  const vars = helpVariables(query.data);
  const steps = [
    {
      icon: Link2,
      title: "1 · Copy the link",
      body: "In the app, tap Share on the video and choose Copy link.",
    },
    {
      icon: ClipboardPaste,
      title: "2 · Paste it here",
      body: "Paste the link into the box above and press Download.",
    },
    {
      icon: Download,
      title: "3 · Download",
      body: "Press Download MP4 to save the video the creator made available.",
    },
  ];
  const faqs: { q: string; a: ReactNode }[] = [
    { q: "Is it free? Do I need an account?", a: "Yes, it’s free and you don’t need to sign in." },
    {
      q: "Which videos can I download?",
      a: "Public videos where the creator allows downloads. If a creator has turned downloads off, we respect that and won’t fetch the video.",
    },
    { q: "Do you keep copies of the videos?", a: FILE_RETENTION_ANSWER },
    {
      q: "How do I ask for a video to be removed?",
      a: (
        <>
          Use the{" "}
          <Link to={REPORT_PATH} className="font-semibold text-accent-ink hover:underline">
            report / copyright removal form
          </Link>
          . We block links we receive valid requests for.
        </>
      ),
    },
    {
      q: "Is SaveStream affiliated with TikTok?",
      a: "No. SaveStream is an independent service and is not affiliated with TikTok or ByteDance.",
    },
  ];
  return (
    <>
      <section className="flex flex-col gap-4" aria-labelledby="vd-how">
        <h2 id="vd-how" className="text-center text-[26px] font-extrabold tracking-[-.025em]">
          How it works
        </h2>
        <div className="grid gap-4 [grid-template-columns:repeat(auto-fit,minmax(min(220px,100%),1fr))]">
          {steps.map((step) => (
            <div key={step.title} className={cn(card, "flex flex-col gap-2.5 p-5")}>
              <span className="grid size-10 place-items-center rounded-[12px] bg-primary-subtle text-accent-ink">
                <step.icon className="size-5" />
              </span>
              <b>{step.title}</b>
              <span className="text-sm text-muted-foreground">{step.body}</span>
            </div>
          ))}
        </div>
      </section>
      <div className="flex flex-wrap items-start gap-6">
        <section
          className="flex min-w-0 flex-[999_1_460px] flex-col gap-2.5"
          aria-labelledby="vd-faq"
        >
          <h2 id="vd-faq" className="text-[26px] font-extrabold tracking-[-.025em]">
            FAQ
          </h2>
          {faqs.map((faq, index) => (
            <details key={faq.q} className={cn(card, "group p-4")} open={index === 0}>
              <summary className="cursor-pointer font-bold marker:text-primary">{faq.q}</summary>
              <p className="mb-0 mt-2.5 text-sm text-muted-foreground">{faq.a}</p>
            </details>
          ))}
        </section>
        <aside
          className="flex flex-[1_1_320px] flex-col gap-3.5 rounded-[20px] border border-primary/30 bg-gradient-to-br from-primary-subtle to-surface p-6 sm:p-7"
          aria-labelledby="vd-promo"
        >
          <span className="inline-flex h-7 w-fit items-center gap-1.5 rounded-full bg-recording-subtle px-2.5 text-xs font-bold text-live-ink">
            <span className="size-1.5 rounded-full bg-recording" />
            Going LIVE?
          </span>
          <h2 id="vd-promo" className="text-[22px] font-extrabold leading-tight tracking-[-.02em]">
            Auto-record your own LIVE in the cloud
          </h2>
          <p className="m-0 text-sm leading-relaxed text-muted-foreground">
            SaveStream watches the channels you own and records every LIVE on our servers, even when
            your laptop is closed. Watch or download later.
          </p>
          <ul className="m-0 list-disc pl-[18px] text-sm leading-[1.8]">
            <li>{vars.trial_minutes} to try it</li>
            <li>No subscription: credits never expire</li>
          </ul>
          <Button className="w-fit" asChild>
            <Link to={status === "authenticated" ? "/overview" : "/sign-up"}>
              {status === "authenticated" ? "Open SaveStream" : "Sign up free"}
            </Link>
          </Button>
        </aside>
      </div>
    </>
  );
}
