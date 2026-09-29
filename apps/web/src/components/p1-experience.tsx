import { Link } from "@tanstack/react-router";
import {
  Check,
  CheckCircle2,
  Clock3,
  Loader2,
  Radio,
  Search,
  ShieldCheck,
  Sparkles,
  X,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import type { Channel } from "../lib/types";
import { usePreferences } from "../lib/preferences";
import { Logo } from "./brand";
import { PreferencesControls } from "./preferences-controls";

const primaryButton =
  "inline-flex h-10 items-center justify-center gap-2 rounded-lg bg-indigo-600 px-4 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-400 disabled:cursor-not-allowed disabled:opacity-50";
const secondaryButton =
  "inline-flex h-10 items-center justify-center gap-2 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-4 text-sm font-semibold transition hover:bg-[var(--subtle)]";

function getCopy(locale: "en" | "vi") {
  if (locale === "vi") {
    return {
      addTitle: "Thêm kênh TikTok",
      addBody: "Dán username hoặc URL TikTok. SaveStream sẽ tìm creator trước khi bật monitoring.",
      inputLabel: "Username hoặc URL TikTok",
      inputPlaceholder: "@creator hoặc https://www.tiktok.com/@creator",
      lookup: "Xem trước creator",
      looking: "Đang tìm creator…",
      preview: "Creator preview",
      platform: "TikTok Live",
      resolved: "Đã nhận diện",
      prototype: "Preview giao diện",
      start: "Thêm & bắt đầu theo dõi",
      added: "Đã bật monitoring",
      addedBody: "Kênh đã sẵn sàng. SaveStream sẽ kiểm tra livestream tự động.",
      close: "Đóng",
      cancel: "Hủy",
      healthHealthy: "Monitoring ổn định",
      healthAttention: "Cần chú ý",
      healthPaused: "Đã tạm dừng",
      lastChecked: "Kiểm tra gần nhất",
      nextCheck: "Lần kiểm tra tiếp theo",
      nextContinuous: "liên tục",
      nextSoon: "~30 giây",
      autoRetry: "Tự động retry khi kiểm tra livestream thất bại.",
      onboardingEyebrow: "Bắt đầu nhanh",
      onboardingTitle: "Thiết lập recording đầu tiên",
      onboardingBody: "Thêm một creator TikTok. Sau đó SaveStream sẽ tự theo dõi và ghi livestream trên cloud.",
      step1: "Thêm kênh TikTok đầu tiên",
      step2: "Bật monitoring tự động",
      step3: "Chờ livestream tiếp theo",
      stepDone: "Hoàn tất",
      stepCurrent: "Đang chờ",
      stepPending: "Tiếp theo",
      creatorReady: "Creator đã sẵn sàng để thêm",
      creatorHint: "Nhập username hoặc URL để xem trước creator.",
      monitoringReady: "Monitoring đã bật",
      monitoringReadyBody: "Bạn có thể đóng trình duyệt. Hệ thống sẽ tiếp tục kiểm tra trên server.",
      dashboard: "Vào dashboard",
      exampleHandle: "@creator",
      accountLabel: "TikTok creator",
    };
  }

  return {
    addTitle: "Add TikTok channel",
    addBody: "Paste a TikTok username or profile URL. SaveStream previews the creator before monitoring starts.",
    inputLabel: "TikTok username or URL",
    inputPlaceholder: "@creator or https://www.tiktok.com/@creator",
    lookup: "Preview creator",
    looking: "Looking up creator…",
    preview: "Creator preview",
    platform: "TikTok Live",
    resolved: "Resolved",
    prototype: "UI preview",
    start: "Add & start monitoring",
    added: "Monitoring enabled",
    addedBody: "The channel is ready. SaveStream will check for livestreams automatically.",
    close: "Close",
    cancel: "Cancel",
    healthHealthy: "Monitoring healthy",
    healthAttention: "Needs attention",
    healthPaused: "Monitoring paused",
    lastChecked: "Last checked",
    nextCheck: "Next check",
    nextContinuous: "continuous",
    nextSoon: "~30 seconds",
    autoRetry: "Automatic retries are enabled if a live check fails.",
    onboardingEyebrow: "Quick start",
    onboardingTitle: "Set up your first recording",
    onboardingBody: "Add a TikTok creator once. SaveStream will monitor and record future livestreams in the cloud.",
    step1: "Add your first TikTok channel",
    step2: "Enable automatic monitoring",
    step3: "Wait for the next livestream",
    stepDone: "Done",
    stepCurrent: "Waiting",
    stepPending: "Next",
    creatorReady: "Creator is ready to add",
    creatorHint: "Enter a username or URL to preview the creator.",
    monitoringReady: "Monitoring is on",
    monitoringReadyBody: "You can close the browser. Server-side monitoring will continue.",
    dashboard: "Go to dashboard",
    exampleHandle: "@creator",
    accountLabel: "TikTok creator",
  };
}

function normalizeHandle(value: string) {
  const trimmed = value.trim();
  if (!trimmed) return "";
  const match = trimmed.match(/tiktok\.com\/@([^/?#]+)/i);
  if (match?.[1]) return `@${match[1].replace(/^@/, "")}`;
  const handle = trimmed.replace(/^@/, "").replace(/[^a-zA-Z0-9._-]/g, "");
  return handle ? `@${handle}` : "";
}

function titleFromHandle(handle: string) {
  const name = handle.replace(/^@/, "").replace(/[._-]+/g, " ").trim();
  if (!name) return "TikTok Creator";
  return name
    .split(" ")
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function initialsFromHandle(handle: string) {
  const words = titleFromHandle(handle).split(" ").filter(Boolean);
  return words.slice(0, 2).map((word) => word[0]).join("").toUpperCase() || "TK";
}

function CreatorPreview({ handle, compact = false }: { handle: string; compact?: boolean }) {
  const { locale } = usePreferences();
  const copy = getCopy(locale);
  const title = titleFromHandle(handle || copy.exampleHandle);
  const initials = initialsFromHandle(handle || copy.exampleHandle);

  return (
    <div className={`rounded-xl border border-[var(--border)] bg-[var(--subtle)] ${compact ? "p-4" : "p-5"}`}>
      <div className="flex items-start gap-4">
        <span className="grid size-12 shrink-0 place-items-center rounded-full bg-gradient-to-br from-fuchsia-500 to-indigo-600 text-sm font-bold text-white">
          {initials}
        </span>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <b className="truncate">{title}</b>
            <span className="inline-flex items-center gap-1 rounded-full border border-emerald-200 bg-emerald-50 px-2 py-0.5 text-[11px] font-semibold text-emerald-700 dark:border-emerald-500/20 dark:bg-emerald-500/10 dark:text-emerald-300">
              <Check className="size-3" /> {copy.resolved}
            </span>
          </div>
          <p className="mt-1 truncate text-sm text-[var(--muted)]">{handle || copy.exampleHandle}</p>
          <p className="mt-2 flex items-center gap-1.5 text-xs text-[var(--muted)]">
            <Radio className="size-3.5 text-indigo-600" /> {copy.platform} · {copy.accountLabel}
          </p>
        </div>
      </div>
    </div>
  );
}

export function AddChannelDialog({
  open,
  onClose,
  onAdded,
}: {
  open: boolean;
  onClose: () => void;
  onAdded?: (handle: string) => void;
}) {
  const { locale } = usePreferences();
  const copy = getCopy(locale);
  const [value, setValue] = useState("");
  const [phase, setPhase] = useState<"idle" | "looking" | "ready" | "added">("idle");
  const handle = useMemo(() => normalizeHandle(value), [value]);

  useEffect(() => {
    if (!open) {
      setValue("");
      setPhase("idle");
      return;
    }
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;

  const lookup = () => {
    if (!handle) return;
    setPhase("looking");
    window.setTimeout(() => setPhase("ready"), 450);
  };

  const add = () => {
    if (!handle) return;
    setPhase("added");
    onAdded?.(handle);
  };

  return (
    <div className="fixed inset-0 z-[80] flex items-end justify-center bg-slate-950/55 p-0 backdrop-blur-sm sm:items-center sm:p-6" onMouseDown={onClose}>
      <section
        role="dialog"
        aria-modal="true"
        aria-labelledby="add-channel-title"
        className="max-h-[92vh] w-full overflow-y-auto rounded-t-2xl border border-[var(--border)] bg-[var(--surface)] shadow-2xl sm:max-w-xl sm:rounded-2xl"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-4 border-b border-[var(--border)] p-5 sm:p-6">
          <div>
            <h2 id="add-channel-title" className="text-xl font-semibold">{copy.addTitle}</h2>
            <p className="mt-1 max-w-md text-sm leading-6 text-[var(--muted)]">{copy.addBody}</p>
          </div>
          <button type="button" onClick={onClose} className="grid size-9 shrink-0 place-items-center rounded-lg hover:bg-[var(--subtle)]" aria-label={copy.close}>
            <X className="size-4" />
          </button>
        </div>

        {phase === "added" ? (
          <div className="p-6">
            <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-5 dark:border-emerald-500/20 dark:bg-emerald-500/10">
              <CheckCircle2 className="size-7 text-emerald-600" />
              <h3 className="mt-4 font-semibold text-emerald-900 dark:text-emerald-200">{copy.added}</h3>
              <p className="mt-1 text-sm leading-6 text-emerald-800/80 dark:text-emerald-200/70">{copy.addedBody}</p>
            </div>
            <div className="mt-5"><CreatorPreview handle={handle} /></div>
            <button type="button" className={`${primaryButton} mt-6 w-full`} onClick={onClose}>{copy.close}</button>
          </div>
        ) : (
          <div className="p-5 sm:p-6">
            <label className="block text-sm font-medium">
              {copy.inputLabel}
              <div className="mt-2 flex items-center gap-2 rounded-lg border border-[var(--border)] bg-[var(--bg)] px-3 focus-within:ring-2 focus-within:ring-indigo-400">
                <Search className="size-4 shrink-0 text-[var(--muted)]" />
                <input
                  autoFocus
                  value={value}
                  onChange={(event) => {
                    setValue(event.target.value);
                    setPhase("idle");
                  }}
                  onKeyDown={(event) => {
                    if (event.key === "Enter") {
                      event.preventDefault();
                      lookup();
                    }
                  }}
                  placeholder={copy.inputPlaceholder}
                  className="h-11 min-w-0 flex-1 bg-transparent text-sm outline-none"
                />
              </div>
            </label>

            {phase === "ready" && handle ? (
              <div className="mt-5">
                <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--muted)]">{copy.preview}</p>
                <CreatorPreview handle={handle} />
              </div>
            ) : (
              <div className="mt-5 rounded-xl border border-dashed border-[var(--border)] p-5 text-sm text-[var(--muted)]">
                {phase === "looking" ? (
                  <span className="flex items-center gap-2"><Loader2 className="size-4 animate-spin" />{copy.looking}</span>
                ) : (
                  <span className="flex items-center gap-2"><Sparkles className="size-4 text-indigo-600" />{copy.creatorHint}</span>
                )}
              </div>
            )}

            <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
              <button type="button" onClick={onClose} className={secondaryButton}>{copy.cancel}</button>
              {phase === "ready" ? (
                <button type="button" onClick={add} className={primaryButton}><Radio className="size-4" />{copy.start}</button>
              ) : (
                <button type="button" onClick={lookup} disabled={!handle || phase === "looking"} className={primaryButton}>
                  {phase === "looking" ? <Loader2 className="size-4 animate-spin" /> : <Search className="size-4" />}
                  {phase === "looking" ? copy.looking : copy.lookup}
                </button>
              )}
            </div>
          </div>
        )}
      </section>
    </div>
  );
}

export function MonitoringHealth({ channel, compact = false }: { channel: Channel; compact?: boolean }) {
  const { locale } = usePreferences();
  const copy = getCopy(locale);
  const kind = !channel.monitoring || channel.status === "Paused" ? "paused" : channel.status === "Error" ? "attention" : "healthy";
  const label = kind === "healthy" ? copy.healthHealthy : kind === "attention" ? copy.healthAttention : copy.healthPaused;
  const dot = kind === "healthy" ? "bg-emerald-500" : kind === "attention" ? "bg-red-500" : "bg-slate-400";
  const text = kind === "healthy" ? "text-emerald-700 dark:text-emerald-300" : kind === "attention" ? "text-red-700 dark:text-red-300" : "text-[var(--muted)]";
  const next = channel.status === "Recording" ? copy.nextContinuous : kind === "paused" ? "—" : copy.nextSoon;

  if (compact) {
    return (
      <div className="min-w-0">
        <span className={`inline-flex items-center gap-2 text-xs font-semibold ${text}`}><span className={`size-2 rounded-full ${dot}`} />{label}</span>
        <p className="mt-1 truncate text-[11px] text-[var(--muted)]">{copy.lastChecked}: {channel.checked}</p>
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-[var(--border)] bg-[var(--subtle)] p-4">
      <div className="flex items-center justify-between gap-3">
        <span className={`inline-flex items-center gap-2 text-sm font-semibold ${text}`}><span className={`size-2.5 rounded-full ${dot}`} />{label}</span>
        <ShieldCheck className="size-4 text-[var(--muted)]" />
      </div>
      <div className="mt-4 grid grid-cols-2 gap-4 text-sm">
        <div>
          <p className="text-xs text-[var(--muted)]">{copy.lastChecked}</p>
          <p className="mt-1 font-medium">{channel.checked}</p>
        </div>
        <div>
          <p className="text-xs text-[var(--muted)]">{copy.nextCheck}</p>
          <p className="mt-1 font-medium">{next}</p>
        </div>
      </div>
      <p className="mt-4 flex items-start gap-2 text-xs leading-5 text-[var(--muted)]">
        <Clock3 className="mt-0.5 size-3.5 shrink-0" /> {copy.autoRetry}
      </p>
    </div>
  );
}

export function OnboardingChecklist() {
  const { locale } = usePreferences();
  const copy = getCopy(locale);
  const [value, setValue] = useState("");
  const [added, setAdded] = useState(false);
  const handle = useMemo(() => normalizeHandle(value), [value]);

  const steps = [
    { label: copy.step1, state: added ? "done" : "current" },
    { label: copy.step2, state: added ? "done" : "pending" },
    { label: copy.step3, state: added ? "current" : "pending" },
  ] as const;

  return (
    <div className="min-h-screen bg-[var(--bg)] text-[var(--fg)]">
      <header className="mx-auto flex h-16 max-w-6xl items-center px-4 sm:px-6">
        <Logo />
        <div className="ml-auto"><PreferencesControls compact /></div>
      </header>

      <main className="mx-auto grid max-w-6xl gap-8 px-4 py-10 sm:px-6 lg:grid-cols-[0.75fr_1.25fr] lg:py-16">
        <section>
          <p className="text-sm font-semibold text-indigo-600">{copy.onboardingEyebrow}</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{copy.onboardingTitle}</h1>
          <p className="mt-4 max-w-xl leading-7 text-[var(--muted)]">{copy.onboardingBody}</p>

          <ol className="mt-8 space-y-3">
            {steps.map((step, index) => (
              <li key={step.label} className="flex items-center gap-3 rounded-xl border border-[var(--border)] bg-[var(--surface)] p-4">
                <span className={`grid size-8 shrink-0 place-items-center rounded-full text-xs font-bold ${
                  step.state === "done"
                    ? "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-300"
                    : step.state === "current"
                      ? "bg-indigo-100 text-indigo-700 dark:bg-indigo-500/15 dark:text-indigo-300"
                      : "bg-[var(--subtle)] text-[var(--muted)]"
                }`}>
                  {step.state === "done" ? <Check className="size-4" /> : index + 1}
                </span>
                <div className="min-w-0">
                  <p className="text-sm font-medium">{step.label}</p>
                  <p className="mt-0.5 text-xs text-[var(--muted)]">
                    {step.state === "done" ? copy.stepDone : step.state === "current" ? copy.stepCurrent : copy.stepPending}
                  </p>
                </div>
              </li>
            ))}
          </ol>
        </section>

        <section className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-5 shadow-xl shadow-indigo-950/5 sm:p-7">
          {!added ? (
            <>
              <label className="block text-sm font-medium">
                {copy.inputLabel}
                <div className="mt-2 flex items-center gap-2 rounded-lg border border-[var(--border)] bg-[var(--bg)] px-3 focus-within:ring-2 focus-within:ring-indigo-400">
                  <Search className="size-4 text-[var(--muted)]" />
                  <input
                    value={value}
                    onChange={(event) => setValue(event.target.value)}
                    placeholder={copy.inputPlaceholder}
                    className="h-11 min-w-0 flex-1 bg-transparent text-sm outline-none"
                  />
                </div>
              </label>

              <div className="mt-5">
                {handle ? <CreatorPreview handle={handle} /> : (
                  <div className="rounded-xl border border-dashed border-[var(--border)] p-6 text-sm text-[var(--muted)]">
                    <Sparkles className="mb-3 size-5 text-indigo-600" />
                    {copy.creatorHint}
                  </div>
                )}
              </div>

              <button type="button" disabled={!handle} onClick={() => setAdded(true)} className={`${primaryButton} mt-6 w-full`}>
                <Radio className="size-4" /> {copy.start}
              </button>
            </>
          ) : (
            <>
              <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-5 dark:border-emerald-500/20 dark:bg-emerald-500/10">
                <CheckCircle2 className="size-7 text-emerald-600" />
                <h2 className="mt-4 text-lg font-semibold text-emerald-900 dark:text-emerald-200">{copy.monitoringReady}</h2>
                <p className="mt-2 text-sm leading-6 text-emerald-800/80 dark:text-emerald-200/70">{copy.monitoringReadyBody}</p>
              </div>
              <div className="mt-5"><CreatorPreview handle={handle} /></div>
              <Link to="/overview" className={`${primaryButton} mt-6 w-full`}>{copy.dashboard}</Link>
            </>
          )}
        </section>
      </main>
    </div>
  );
}
