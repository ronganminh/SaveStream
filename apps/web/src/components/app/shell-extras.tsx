import { Link, useNavigate, useRouterState } from "@tanstack/react-router";
import {
  Activity,
  AlertCircle,
  Check,
  CircleHelp,
  CreditCard,
  Flag,
  Lock,
  Mail,
  Search,
} from "lucide-react";
import {
  useCallback,
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
  type KeyboardEvent as ReactKeyboardEvent,
  type ReactNode,
} from "react";
import { toast } from "sonner";

import { recentFailedRequestIds } from "@/api/client";
import { authErrorMessage } from "@/api/auth";
import { useAuth } from "@/auth/auth-context";
import { IconTile } from "@/components/auth/auth-ui";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useResendVerificationMutation } from "@/hooks/use-account-settings";
import {
  useChannelsData,
  useCreditBalanceData,
  usePublicPricingData,
  useRecordingsData,
} from "@/hooks/use-domain-data";
import { isDemoMode } from "@/lib/app-config";
import { cn } from "@/lib/utils";
import { repositories, type ChannelModel, type RecordingModel } from "@/repositories";
import { CreatorAvatar, StatusBadge } from "@/components/app-components";

/*
 * App chrome from the Claude Design handoff (AppTopbar / AppSidebar,
 * GlobalSearch, HelpMenu, ReportProblemModal, CreditStates, EmailUnverified,
 * SessionExpired).
 */

// ---------------------------------------------------------------------------------
// Credits
// ---------------------------------------------------------------------------------

/** Below this many recording minutes the low-credit banner shows. */
export const LOW_CREDIT_MINUTES = 120;
const LOW_CREDIT_SNOOZE_KEY = "ss_low_credit_snoozed_until";
const LOW_CREDIT_SNOOZE_MS = 24 * 60 * 60 * 1000;

export type CreditSummary = {
  loaded: boolean;
  minutes: number;
  /** "12.4 h" or "45 min". */
  label: string;
  /** 0–100, against the smallest pack (a full Starter pack reads 100%). */
  percent: number;
  state: "ok" | "low" | "out";
};

export function formatRecordingTime(minutes: number): string {
  if (minutes <= 0) return "0 h";
  if (minutes < 60) return `${Math.max(1, Math.round(minutes))} min`;
  const hours = minutes / 60;
  return `${hours >= 100 ? Math.round(hours) : Number(hours.toFixed(1))} h`;
}

export function useCreditSummary(): CreditSummary {
  const { query: balanceQuery } = useCreditBalanceData();
  const { query: pricingQuery } = usePublicPricingData();
  const rate = pricingQuery.data?.recording_rate;
  const minutesPerCredit =
    rate && rate.credits_per_unit > 0 ? rate.unit_seconds / 60 / rate.credits_per_unit : 1;
  const smallestPackMinutes = Math.min(
    ...(pricingQuery.data?.packages ?? []).map((pack) => pack.recording_minutes ?? pack.credits),
  );
  const available = balanceQuery.data?.available ?? 0;
  const minutes = Math.max(0, available * minutesPerCredit);
  const reference =
    Number.isFinite(smallestPackMinutes) && smallestPackMinutes > 0 ? smallestPackMinutes : 3000;
  return {
    loaded: Boolean(balanceQuery.data),
    minutes,
    label: formatRecordingTime(minutes),
    percent: Math.min(100, Math.round((minutes / reference) * 100)),
    state: minutes <= 0 ? "out" : minutes < LOW_CREDIT_MINUTES ? "low" : "ok",
  };
}

function readSnooze(): number {
  try {
    return Number(window.sessionStorage.getItem(LOW_CREDIT_SNOOZE_KEY) ?? 0) || 0;
  } catch {
    return 0;
  }
}

function Banner({
  tone,
  icon,
  title,
  body,
  children,
  role = "status",
}: {
  tone: "warn" | "err";
  icon: ReactNode;
  title: ReactNode;
  body?: ReactNode;
  children?: ReactNode;
  role?: "status" | "alert";
}) {
  return (
    <div
      role={role}
      className={cn(
        "flex flex-col gap-3 rounded-[14px] border px-4 py-3.5 sm:flex-row sm:items-center",
        tone === "warn" && "border-warning/30 bg-warning-subtle",
        tone === "err" && "border-destructive/30 bg-destructive/10",
      )}
    >
      <div className="flex min-w-0 flex-1 items-start gap-3 sm:items-center">
        <span
          aria-hidden="true"
          className={cn(
            "grid size-10 shrink-0 place-items-center rounded-[12px] bg-surface",
            tone === "warn" ? "text-warning" : "text-destructive",
          )}
        >
          {icon}
        </span>
        <span className="min-w-0">
          <b className="block text-sm font-bold">{title}</b>
          {body && <span className="mt-0.5 block text-sm text-muted-foreground">{body}</span>}
        </span>
      </div>
      {children && <div className="flex shrink-0 items-center gap-2 sm:ml-auto">{children}</div>}
    </div>
  );
}

/** Low / out-of-credits banner shown under the top bar on every app page. */
export function CreditBanner() {
  const credits = useCreditSummary();
  const { query: channelsQuery } = useChannelsData();
  const [snoozedUntil, setSnoozedUntil] = useState(0);
  useEffect(() => setSnoozedUntil(readSnooze()), []);
  const path = useRouterState({ select: (s) => s.location.pathname });
  if (!credits.loaded || credits.state === "ok" || path.startsWith("/billing")) return null;

  if (credits.state === "out") {
    const monitored = (channelsQuery.data ?? []).filter((channel) => channel.monitoring).length;
    return (
      <Banner
        tone="err"
        role="alert"
        icon={<AlertCircle className="size-5" />}
        title="You’re out of credits — new LIVEs won’t be recorded"
        body={
          monitored > 0
            ? `We’re still watching your ${monitored === 1 ? "channel" : `${monitored} channels`} for free. Add credits and recording resumes automatically.`
            : "Monitoring stays free. Add credits to record your next LIVE."
        }
      >
        <Button asChild size="sm">
          <Link to="/billing">Buy credits</Link>
        </Button>
      </Banner>
    );
  }

  if (snoozedUntil > Date.now()) return null;
  return (
    <Banner
      tone="warn"
      icon={<CreditCard className="size-5" />}
      title={`Only ${credits.label} of credits left`}
      body="Top up so your next LIVE isn’t cut short."
    >
      <Button
        variant="ghost"
        size="sm"
        onClick={() => {
          const until = Date.now() + LOW_CREDIT_SNOOZE_MS;
          try {
            window.sessionStorage.setItem(LOW_CREDIT_SNOOZE_KEY, String(until));
          } catch {
            /* storage blocked: snooze for this page view only */
          }
          setSnoozedUntil(until);
        }}
      >
        Remind me later
      </Button>
      <Button asChild size="sm">
        <Link to="/billing">Buy credits</Link>
      </Button>
    </Banner>
  );
}

/** Shown while the signed-in account has not confirmed its email address. */
export function EmailUnverifiedBanner() {
  const { user } = useAuth();
  const resend = useResendVerificationMutation();
  const [sent, setSent] = useState(false);
  if (isDemoMode || !user || user.email_verified) return null;
  return (
    <Banner
      tone="warn"
      icon={<Mail className="size-5" />}
      title="Verify your email address"
      body={
        <>
          We sent a verification link to <b className="text-foreground">{user.email}</b>. It expires
          after 30 minutes; you can send a new one any time.
        </>
      }
    >
      <Button
        variant="outline"
        size="sm"
        disabled={resend.isPending || sent}
        onClick={() =>
          resend.mutate(user.email, {
            onSuccess: () => setSent(true),
            onError: (error) => toast.error(authErrorMessage(error)),
          })
        }
      >
        {sent ? (
          <>
            <Check /> Link sent
          </>
        ) : resend.isPending ? (
          "Sending…"
        ) : (
          "Resend link"
        )}
      </Button>
    </Banner>
  );
}

export function GlobalBanners() {
  return (
    <div className="mx-auto flex max-w-[1440px] flex-col gap-3 px-4 pt-4 empty:hidden sm:px-6 lg:px-8 lg:pt-6">
      <EmailUnverifiedBanner />
      <CreditBanner />
    </div>
  );
}

// ---------------------------------------------------------------------------------
// Report a problem
// ---------------------------------------------------------------------------------

const REPORT_CATEGORIES = [
  "Recording missing or failed",
  "Playback or download",
  "Payment or credits",
  "Account or sign-in",
  "Something else",
] as const;

export type ReportContext = {
  recordingId: string;
  title: string;
  handle?: string;
};

export function reportReference(reportId: string): string {
  return `PR-${reportId.replace(/-/g, "").slice(0, 6).toUpperCase()}`;
}

export function ReportProblemDialog({
  open,
  onOpenChange,
  recording,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  recording?: ReportContext | null;
}) {
  const { user } = useAuth();
  const path = useRouterState({ select: (s) => s.location.pathname });
  const categories = recording
    ? ([
        "Playback or download",
        ...REPORT_CATEGORIES.filter((c) => c !== "Playback or download"),
      ] as const)
    : REPORT_CATEGORIES;
  const [category, setCategory] = useState<string>(categories[0]);
  const [message, setMessage] = useState("");
  const [diagnostics, setDiagnostics] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [reference, setReference] = useState<string | null>(null);
  const ids = useId();

  useEffect(() => {
    if (!open) return;
    setCategory(categories[0]);
    setMessage("");
    setDiagnostics(true);
    setError(null);
    setReference(null);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, recording?.recordingId]);

  const submit = async () => {
    if (message.trim().length < 3) {
      setError("Tell us a little about what happened.");
      return;
    }
    setSending(true);
    setError(null);
    try {
      const result = await repositories.support.createReport({
        message: `[${category}] ${message.trim()}`,
        recording_id: recording?.recordingId ?? null,
        diagnostics: diagnostics
          ? {
              category,
              source: "web",
              page: path,
              os: typeof navigator !== "undefined" ? navigator.platform || "web" : "web",
              user_agent: typeof navigator !== "undefined" ? navigator.userAgent : "",
              viewport:
                typeof window !== "undefined" ? `${window.innerWidth}x${window.innerHeight}` : "",
              request_ids: recentFailedRequestIds(),
            }
          : { category, source: "web" },
      });
      setReference(reportReference(result.report_id));
    } catch (caught) {
      setError(authErrorMessage(caught));
    } finally {
      setSending(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-[540px] gap-5 rounded-[20px] p-7">
        {reference ? (
          <div className="flex flex-col items-center gap-3.5 py-3 text-center">
            <IconTile tone="ok" size="md">
              <Check className="size-6" />
            </IconTile>
            <DialogTitle className="text-xl font-extrabold">Thanks — we’re on it</DialogTitle>
            <DialogDescription className="text-sm text-muted-foreground">
              Reference <b className="font-mono text-foreground">{reference}</b>. We’ll reply to{" "}
              {user?.email ?? "your account email"}.
            </DialogDescription>
            <Button onClick={() => onOpenChange(false)}>Done</Button>
          </div>
        ) : (
          <>
            <div className="space-y-2 pr-6">
              <DialogTitle className="text-xl font-extrabold">Report a problem</DialogTitle>
              <DialogDescription className="text-sm text-muted-foreground">
                Tell us what went wrong. For copyright or abuse concerns, follow the{" "}
                <Link
                  to="/copyright"
                  className="font-semibold text-accent-ink underline-offset-4 hover:underline"
                >
                  Copyright &amp; Takedown Policy
                </Link>{" "}
                instead.
              </DialogDescription>
            </div>
            <div className="space-y-1.5">
              <label htmlFor={`${ids}-category`} className="text-sm font-semibold">
                What’s it about?
              </label>
              <select
                id={`${ids}-category`}
                value={category}
                onChange={(event) => setCategory(event.target.value)}
                className="h-11 w-full rounded-[12px] border bg-surface px-3 text-sm focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-ring/25"
              >
                {categories.map((item) => (
                  <option key={item}>{item}</option>
                ))}
              </select>
            </div>
            {recording && (
              <div className="flex items-center gap-2.5 rounded-[12px] bg-surface-2 px-3 py-2.5">
                <span
                  aria-hidden="true"
                  className="h-[38px] w-7 shrink-0 rounded-md bg-gradient-to-br from-thumbnail-one to-thumbnail-three"
                />
                <span className="min-w-0">
                  <b className="block truncate text-sm">{recording.title}</b>
                  <span className="block truncate font-mono text-xs text-muted-foreground">
                    {recording.handle ? `${recording.handle} · ` : ""}attached automatically
                  </span>
                </span>
              </div>
            )}
            <div className="space-y-1.5">
              <label htmlFor={`${ids}-message`} className="text-sm font-semibold">
                What happened?
              </label>
              <textarea
                id={`${ids}-message`}
                value={message}
                onChange={(event) => setMessage(event.target.value)}
                maxLength={5000}
                placeholder="What did you expect, and what happened instead?"
                className="min-h-[110px] w-full rounded-[12px] border bg-surface px-3 py-2.5 text-sm focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-ring/25"
              />
            </div>
            <label className="flex cursor-pointer items-start gap-2.5 text-sm">
              <input
                type="checkbox"
                checked={diagnostics}
                onChange={(event) => setDiagnostics(event.target.checked)}
                className="mt-0.5 size-4 accent-primary"
              />
              <span>Include diagnostics: this page ({path}), browser and recent request IDs</span>
            </label>
            {error && (
              <p role="alert" className="text-sm font-medium text-destructive">
                {error}
              </p>
            )}
            <div className="flex justify-end gap-2.5">
              <Button variant="ghost" onClick={() => onOpenChange(false)}>
                Cancel
              </Button>
              <Button onClick={() => void submit()} disabled={sending}>
                {sending ? "Sending…" : "Send report"}
              </Button>
            </div>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}

// ---------------------------------------------------------------------------------
// Help menu
// ---------------------------------------------------------------------------------

export function HelpMenu() {
  const [reportOpen, setReportOpen] = useState(false);
  const navigate = useNavigate();
  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon" aria-label="Help menu">
            <CircleHelp />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-[280px] p-2">
          <DropdownMenuItem
            onSelect={() => void navigate({ to: "/help" })}
            className="min-h-10 gap-3 font-semibold"
          >
            <CircleHelp /> Help center
          </DropdownMenuItem>
          <DropdownMenuItem
            onSelect={() => void navigate({ to: "/status" })}
            className="min-h-10 gap-3 font-semibold"
          >
            <Activity /> System status
          </DropdownMenuItem>
          <DropdownMenuItem
            onSelect={() => void navigate({ to: "/contact" })}
            className="min-h-10 gap-3 font-semibold"
          >
            <Mail /> Contact support
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem
            onSelect={() => setReportOpen(true)}
            className="min-h-10 gap-3 font-semibold"
          >
            <Flag /> Report a problem
          </DropdownMenuItem>
          <p className="px-3 pb-1 pt-1.5 text-xs text-muted-foreground">
            Sends this page and diagnostics to our team.
          </p>
        </DropdownMenuContent>
      </DropdownMenu>
      <ReportProblemDialog open={reportOpen} onOpenChange={setReportOpen} />
    </>
  );
}

// ---------------------------------------------------------------------------------
// Global search (top bar dropdown, ⌘K)
// ---------------------------------------------------------------------------------

const MAX_CHANNEL_RESULTS = 4;
const MAX_RECORDING_RESULTS = 5;

function Highlight({ text, query }: { text: string; query: string }) {
  const index = query ? text.toLowerCase().indexOf(query.toLowerCase()) : -1;
  if (index < 0) return <>{text}</>;
  return (
    <>
      {text.slice(0, index)}
      <mark className="rounded-[3px] bg-primary-subtle text-accent-ink">
        {text.slice(index, index + query.length)}
      </mark>
      {text.slice(index + query.length)}
    </>
  );
}

type SearchResult =
  { kind: "channel"; channel: ChannelModel } | { kind: "recording"; recording: RecordingModel };

export function searchWorkspace(
  query: string,
  channels: ChannelModel[],
  recordings: RecordingModel[],
): { channels: ChannelModel[]; recordings: RecordingModel[] } {
  const needle = query.trim().toLowerCase().replace(/^@/, "");
  if (!needle) return { channels: [], recordings: [] };
  const matches = (...values: (string | undefined)[]) =>
    values.some((value) => value?.toLowerCase().replace(/^@/, "").includes(needle));
  return {
    channels: channels.filter((c) => matches(c.name, c.handle)).slice(0, MAX_CHANNEL_RESULTS),
    recordings: recordings
      .filter((r) => matches(r.title, r.handle, r.date))
      .slice(0, MAX_RECORDING_RESULTS),
  };
}

export function GlobalSearch() {
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const boxRef = useRef<HTMLDivElement>(null);
  const navigate = useNavigate();
  const listId = useId();
  const { query: channelsQuery } = useChannelsData();
  const { query: recordingsQuery } = useRecordingsData();

  const results = useMemo(
    () => searchWorkspace(query, channelsQuery.data ?? [], recordingsQuery.data ?? []),
    [query, channelsQuery.data, recordingsQuery.data],
  );
  const flat: SearchResult[] = useMemo(
    () => [
      ...results.channels.map((channel) => ({ kind: "channel" as const, channel })),
      ...results.recordings.map((recording) => ({ kind: "recording" as const, recording })),
    ],
    [results],
  );

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        inputRef.current?.focus();
        setOpen(true);
      }
    };
    const onPointer = (event: PointerEvent) => {
      if (!boxRef.current?.contains(event.target as Node)) setOpen(false);
    };
    window.addEventListener("keydown", onKey);
    window.addEventListener("pointerdown", onPointer);
    return () => {
      window.removeEventListener("keydown", onKey);
      window.removeEventListener("pointerdown", onPointer);
    };
  }, []);

  useEffect(() => setActive(0), [query]);

  const openResult = useCallback(
    (result: SearchResult) => {
      setOpen(false);
      setQuery("");
      inputRef.current?.blur();
      if (result.kind === "channel") {
        void navigate({ to: "/channels/$id", params: { id: result.channel.id } });
      } else {
        void navigate({ to: "/recordings/$id", params: { id: result.recording.id } });
      }
    },
    [navigate],
  );

  const onKeyDown = (event: ReactKeyboardEvent<HTMLInputElement>) => {
    if (event.key === "Escape") {
      setOpen(false);
      inputRef.current?.blur();
    } else if (event.key === "ArrowDown") {
      event.preventDefault();
      setOpen(true);
      setActive((current) => Math.min(flat.length - 1, current + 1));
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      setActive((current) => Math.max(0, current - 1));
    } else if (event.key === "Enter" && flat[active]) {
      event.preventDefault();
      openResult(flat[active]);
    }
  };

  const showPanel = open && query.trim().length > 0;
  let index = -1;
  const optionId = (i: number) => `${listId}-opt-${i}`;

  return (
    <div ref={boxRef} className="relative hidden max-w-[420px] flex-1 md:block">
      <label
        className={cn(
          "flex h-[42px] items-center gap-2.5 rounded-[12px] border bg-surface-2 px-3 text-muted-foreground transition-shadow",
          showPanel && "border-primary bg-surface shadow-[0_0_0_4px_var(--color-ring)]/20",
        )}
      >
        <Search className="size-[18px] shrink-0" aria-hidden="true" />
        <input
          ref={inputRef}
          type="search"
          role="combobox"
          aria-label="Search channels or recordings"
          aria-expanded={showPanel}
          aria-controls={listId}
          aria-activedescendant={showPanel && flat[active] ? optionId(active) : undefined}
          placeholder="Search channels or recordings"
          value={query}
          onChange={(event) => {
            setQuery(event.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          onKeyDown={onKeyDown}
          className="min-w-0 flex-1 bg-transparent text-sm text-foreground outline-none placeholder:text-muted-foreground [&::-webkit-search-cancel-button]:hidden"
        />
        <kbd className="rounded-md border border-line-strong bg-surface px-1.5 py-0.5 font-mono text-[11px] font-semibold">
          {showPanel ? "Esc" : "⌘K"}
        </kbd>
      </label>
      {showPanel && (
        <div
          id={listId}
          role="listbox"
          aria-label="Search results"
          className="absolute left-0 top-[calc(100%+6px)] z-[var(--z-dropdown,50)] w-[min(560px,calc(100vw-2rem))] overflow-hidden rounded-[16px] border bg-popover p-2 shadow-lg"
        >
          {flat.length === 0 && (
            <div className="px-3 py-5 text-center">
              <p className="text-sm font-semibold">No results for “{query.trim()}”</p>
              <p className="mt-1 text-xs text-muted-foreground">
                Try a creator name, @handle, or recording date.
              </p>
            </div>
          )}
          {results.channels.length > 0 && (
            <p className="px-3 pb-1.5 pt-2 text-[11px] font-bold uppercase tracking-[.08em] text-muted-foreground">
              Channels · {results.channels.length}
            </p>
          )}
          {results.channels.map((channel) => {
            index += 1;
            const i = index;
            return (
              <button
                key={channel.id}
                id={optionId(i)}
                type="button"
                role="option"
                aria-selected={active === i}
                onMouseEnter={() => setActive(i)}
                onClick={() => openResult({ kind: "channel", channel })}
                className={cn(
                  "flex min-h-[52px] w-full items-center gap-3 rounded-[10px] px-3 text-left",
                  active === i && "bg-primary-subtle",
                )}
              >
                <CreatorAvatar channel={channel} size="sm" />
                <span className="min-w-0 flex-1">
                  <b className="block truncate text-sm">
                    <Highlight text={channel.handle} query={query.trim().replace(/^@/, "")} />
                  </b>
                  <span className="block truncate text-xs text-muted-foreground">
                    <Highlight text={channel.name} query={query.trim()} />
                    {" · "}
                    {channel.monitoring ? "Monitoring on" : "Monitoring paused"}
                    {channel.monitoring
                      ? channel.autoRecord
                        ? " · auto-record on"
                        : " · auto-record off"
                      : ""}
                  </span>
                </span>
                <StatusBadge status={channel.status} />
              </button>
            );
          })}
          {results.recordings.length > 0 && (
            <p className="px-3 pb-1.5 pt-3 text-[11px] font-bold uppercase tracking-[.08em] text-muted-foreground">
              Recordings · {results.recordings.length}
            </p>
          )}
          {results.recordings.map((recording) => {
            index += 1;
            const i = index;
            return (
              <button
                key={recording.id}
                id={optionId(i)}
                type="button"
                role="option"
                aria-selected={active === i}
                onMouseEnter={() => setActive(i)}
                onClick={() => openResult({ kind: "recording", recording })}
                className={cn(
                  "flex min-h-14 w-full items-center gap-3 rounded-[10px] px-3 text-left",
                  active === i && "bg-primary-subtle",
                )}
              >
                <span
                  aria-hidden="true"
                  className={cn("h-10 w-[30px] shrink-0 rounded-md", recording.color)}
                />
                <span className="min-w-0 flex-1">
                  <b className="block truncate text-sm">
                    <Highlight text={recording.title} query={query.trim()} />
                  </b>
                  <span className="block truncate text-xs text-muted-foreground">
                    {recording.handle} · {recording.date} · {recording.duration}
                  </span>
                </span>
                <StatusBadge status={recording.status} />
              </button>
            );
          })}
          {flat.length > 0 && (
            <div className="mt-1.5 hidden items-center justify-between gap-3 border-t px-3 pb-1 pt-3 text-xs text-muted-foreground sm:flex">
              <span>
                <kbd className="font-mono">↑</kbd> <kbd className="font-mono">↓</kbd> to move ·{" "}
                <kbd className="font-mono">↵</kbd> to open
              </span>
              <Link
                to="/recordings"
                onClick={() => setOpen(false)}
                className="font-semibold text-accent-ink hover:underline"
              >
                All recordings →
              </Link>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------------
// Session expired
// ---------------------------------------------------------------------------------

export function SessionExpiredDialog() {
  const { acknowledgeSessionExpired } = useAuth();
  const navigate = useNavigate();
  const signInAgain = () => {
    acknowledgeSessionExpired();
    void navigate({ to: "/sign-in", replace: true });
  };
  return (
    <div className="grid min-h-screen place-items-center bg-overlay px-4">
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="session-expired-title"
        className="flex w-full max-w-[440px] flex-col items-center gap-5 rounded-[20px] border bg-surface p-7 text-center shadow-lg"
      >
        <IconTile tone="accent" size="md">
          <Lock className="size-6" />
        </IconTile>
        <div className="space-y-2">
          <h2 id="session-expired-title" className="text-xl font-extrabold">
            Your session expired
          </h2>
          <p className="text-sm text-muted-foreground">
            For your security you were signed out. Your channels are still being monitored and
            recorded.
          </p>
        </div>
        <Button size="lg" className="w-full" onClick={signInAgain} autoFocus>
          Sign in again
        </Button>
        <Link
          to="/"
          onClick={() => acknowledgeSessionExpired()}
          className="text-sm font-semibold text-accent-ink hover:underline"
        >
          Go to the home page
        </Link>
      </div>
    </div>
  );
}
