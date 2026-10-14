import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import { Link, useRouterState } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Clock3, RotateCcw, WifiOff, Wrench } from "lucide-react";
import { toast } from "sonner";

import { apiClient } from "@/api/client";
import { Logo } from "@/components/app-components";
import { Button } from "@/components/ui/button";
import { isDemoMode } from "@/lib/app-config";
import { SUPPORT_EMAIL } from "@/lib/support";
import { cn } from "@/lib/utils";

/**
 * Full-page system states (design "RestoringSession / Maintenance /
 * ServerError / Offline / OfflineBanner").
 */

function Skeleton({ className, width }: { className?: string; width?: number }) {
  return (
    <span
      className={cn("block animate-pulse rounded-md bg-surface-2", className)}
      style={width ? { width } : undefined}
    />
  );
}

/** App boot state: a skeleton of the dashboard with a "Restoring…" pill. */
export function RestoringSessionScreen({
  message = "Restoring your session…",
}: {
  message?: string;
}) {
  return (
    <div className="relative flex min-h-screen bg-background" aria-busy="true">
      <aside
        aria-hidden="true"
        className="hidden w-[260px] shrink-0 flex-col gap-3.5 border-r bg-surface p-5 lg:flex"
      >
        <div className="pb-4">
          <Logo />
        </div>
        {[110, 90, 120, 100, 80].map((width) => (
          <div key={width} className="flex items-center gap-3 px-1">
            <Skeleton className="size-5" />
            <Skeleton className="h-3" width={width} />
          </div>
        ))}
        <Skeleton className="mt-auto h-[110px] rounded-[14px]" />
      </aside>
      <div className="flex min-w-0 flex-1 flex-col" aria-hidden="true">
        <div className="flex h-[72px] items-center gap-3 border-b px-6">
          <Skeleton className="h-10 w-full max-w-[380px] rounded-xl" />
          <Skeleton className="ml-auto h-9 w-[110px] rounded-[10px]" />
          <Skeleton className="size-11 rounded-xl" />
          <Skeleton className="size-9 rounded-full" />
        </div>
        <div className="flex flex-col gap-6 p-6 lg:p-8">
          <div className="flex flex-col gap-2">
            <Skeleton className="h-7 w-[220px]" />
            <Skeleton className="h-3.5 w-[320px] max-w-full" />
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            {[0, 1, 2].map((card) => (
              <div key={card} className="flex flex-col gap-3.5 rounded-2xl border bg-surface p-5">
                <Skeleton className="h-3 w-[90px]" />
                <Skeleton className="h-7 w-[120px]" />
                <Skeleton className="h-2" />
              </div>
            ))}
          </div>
          <div className="overflow-hidden rounded-2xl border bg-surface">
            {[180, 140, 200].map((width) => (
              <div key={width} className="flex items-center gap-3 border-b px-5 py-4 last:border-0">
                <Skeleton className="size-9 rounded-full" />
                <Skeleton className="h-3" width={width} />
                <Skeleton className="ml-auto h-[22px] w-[70px] rounded-full" />
              </div>
            ))}
          </div>
        </div>
      </div>
      <div
        role="status"
        className="absolute left-1/2 top-24 flex -translate-x-1/2 items-center gap-2.5 rounded-full border bg-surface py-2.5 pl-3 pr-[18px] shadow-dashboard"
      >
        <span className="size-5 animate-spin rounded-full border-[2.5px] border-primary-subtle border-t-primary" />
        <span className="text-sm font-semibold">{message}</span>
      </div>
    </div>
  );
}

function SystemFrame({ children }: { children: ReactNode }) {
  return (
    <div className="relative flex min-h-screen flex-col overflow-hidden bg-background">
      <header className="relative border-b bg-background/80 backdrop-blur">
        <nav className="mx-auto flex h-[72px] max-w-[1200px] items-center px-6" aria-label="Main">
          <Logo />
        </nav>
      </header>
      <div aria-hidden className="hero-glow" />
      <main className="relative flex flex-1 flex-col items-center justify-center gap-5 px-6 py-20 text-center">
        {children}
      </main>
      <footer className="relative border-t">
        <div className="mx-auto flex max-w-[1200px] flex-wrap items-center gap-x-6 gap-y-2 px-6 py-6 text-sm text-muted-foreground">
          <span>© 2026 SaveStream</span>
          <Link to="/status" className="hover:text-foreground">
            System status
          </Link>
          <a href={`mailto:${SUPPORT_EMAIL}`} className="hover:text-foreground">
            {SUPPORT_EMAIL}
          </a>
        </div>
      </footer>
    </div>
  );
}

function Badge({ tone, children }: { tone: "warn" | "off"; children: ReactNode }) {
  return (
    <span
      className={cn(
        "inline-flex h-7 items-center gap-1.5 rounded-full px-3 text-xs font-bold",
        tone === "warn" ? "bg-warning-subtle text-warning" : "bg-surface-2 text-muted-foreground",
      )}
    >
      <span className="size-1.5 rounded-full bg-current" />
      {children}
    </span>
  );
}

function formatEta(eta: string) {
  const date = new Date(eta);
  if (Number.isNaN(date.getTime())) return null;
  return date.toLocaleString("en-US", {
    timeZone: "UTC",
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

export function MaintenanceScreen({ eta, onRetry }: { eta: string | null; onRetry: () => void }) {
  const etaLabel = eta ? formatEta(eta) : null;
  return (
    <SystemFrame>
      <span className="grid size-[88px] place-items-center rounded-[28px] bg-warning-subtle text-warning">
        <Wrench className="size-10" aria-hidden="true" />
      </span>
      <Badge tone="warn">Scheduled maintenance</Badge>
      <h1 className="text-[38px] font-extrabold tracking-[-0.03em]">
        We’re making SaveStream better
      </h1>
      <p className="max-w-[520px] text-lg text-muted-foreground">
        The dashboard is offline for planned maintenance. Your channels, recordings and credits are
        safe.
      </p>
      <div className="flex items-center gap-3.5 rounded-2xl border bg-surface px-5 py-3.5 text-sm">
        <Clock3 className="size-5" aria-hidden="true" />
        {etaLabel ? (
          <span>
            Expected back by <b className="font-mono">{etaLabel}</b> UTC
          </span>
        ) : (
          <span>We’ll be back as soon as possible.</span>
        )}
      </div>
      <div className="flex flex-wrap justify-center gap-3">
        <Button size="lg" asChild>
          <Link to="/status">Check the Status page</Link>
        </Button>
        <Button size="lg" variant="outline" onClick={onRetry}>
          <RotateCcw />
          Try again
        </Button>
      </div>
    </SystemFrame>
  );
}

export function ServerErrorScreen({
  requestId,
  onRetry,
}: {
  requestId?: string | undefined;
  onRetry: () => void;
}) {
  return (
    <SystemFrame>
      <div
        aria-hidden="true"
        className="text-[120px] font-extrabold leading-none tracking-[-0.06em] text-primary"
      >
        500
      </div>
      <h1 className="text-4xl font-extrabold tracking-[-0.025em]">Something went wrong</h1>
      <p className="max-w-[500px] text-lg text-muted-foreground">
        That’s on us, not you. Any recording that was already running keeps going. Try again in a
        moment.
      </p>
      <div className="flex flex-wrap justify-center gap-3">
        <Button size="lg" onClick={onRetry}>
          <RotateCcw />
          Retry
        </Button>
        <Button size="lg" variant="outline" asChild>
          <a href="/overview">Go to dashboard</a>
        </Button>
      </div>
      {requestId && (
        <div className="flex items-center gap-3 rounded-2xl border bg-surface px-4 py-3">
          <span className="text-sm text-muted-foreground">Request ID</span>
          <b className="font-mono text-sm">{requestId}</b>
          <Button
            size="sm"
            variant="ghost"
            onClick={() => {
              void navigator.clipboard?.writeText(requestId);
              toast.success("Request ID copied");
            }}
          >
            Copy
          </Button>
        </div>
      )}
      <p className="text-sm text-muted-foreground">
        Still broken? Email{" "}
        <a href={`mailto:${SUPPORT_EMAIL}`} className="font-semibold text-accent-ink">
          {SUPPORT_EMAIL}
        </a>
        {requestId ? " with the request ID" : ""}, or{" "}
        <Link to="/status" className="font-semibold text-accent-ink">
          check status
        </Link>
        .
      </p>
    </SystemFrame>
  );
}

const OFFLINE_RETRY_SECONDS = 15;

function useCountdown(active: boolean, seconds: number, onDone: () => void) {
  const [left, setLeft] = useState(seconds);
  const done = useRef(onDone);
  done.current = onDone;
  useEffect(() => {
    setLeft(seconds);
    if (!active) return;
    const timer = setInterval(() => {
      setLeft((current) => {
        if (current <= 1) {
          done.current();
          return seconds;
        }
        return current - 1;
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [active, seconds]);
  return left;
}

function useOnline() {
  const [online, setOnline] = useState(true);
  useEffect(() => {
    if (typeof navigator === "undefined") return;
    setOnline(navigator.onLine);
    const up = () => setOnline(true);
    const down = () => setOnline(false);
    window.addEventListener("online", up);
    window.addEventListener("offline", down);
    return () => {
      window.removeEventListener("online", up);
      window.removeEventListener("offline", down);
    };
  }, []);
  return online;
}

export function OfflineScreen({
  onRetry,
  secondsLeft,
}: {
  onRetry: () => void;
  secondsLeft: number;
}) {
  return (
    <SystemFrame>
      <span className="grid size-[88px] place-items-center rounded-[28px] bg-surface-2 text-muted-foreground">
        <WifiOff className="size-10" aria-hidden="true" />
      </span>
      <Badge tone="off">Offline</Badge>
      <h1 className="text-4xl font-extrabold tracking-[-0.025em]">You’re offline</h1>
      <p className="max-w-[500px] text-lg text-muted-foreground">
        We can’t reach SaveStream from this device. Check your connection — your channels are still
        monitored and recorded in the cloud.
      </p>
      <Button size="lg" onClick={onRetry}>
        <RotateCcw />
        Try again
      </Button>
      <p className="text-xs text-muted-foreground">
        Retrying automatically in{" "}
        <span className="font-mono">0:{String(secondsLeft).padStart(2, "0")}</span>
      </p>
    </SystemFrame>
  );
}

/** Full-page offline state when the first load fails without a connection. */
export function OfflineErrorScreen({ onRetry }: { onRetry: () => void }) {
  const left = useCountdown(true, OFFLINE_RETRY_SECONDS, onRetry);
  return <OfflineScreen onRetry={onRetry} secondsLeft={left} />;
}

/** Dark "Connection lost" banner shown over the app while the device is offline. */
export function OfflineBanner() {
  const online = useOnline();
  const queryClient = useQueryClient();
  const retry = useCallback(() => {
    if (typeof navigator !== "undefined" && navigator.onLine) {
      void queryClient.invalidateQueries();
    }
  }, [queryClient]);
  const left = useCountdown(!online, OFFLINE_RETRY_SECONDS, retry);
  if (online) return null;
  return (
    <div
      role="status"
      aria-live="polite"
      className="fixed inset-x-4 top-4 z-[60] mx-auto max-w-3xl"
    >
      <div className="flex flex-wrap items-center gap-3 rounded-2xl border border-[#15122B] bg-[#15122B] px-4 py-3 text-white shadow-dashboard">
        <span className="min-w-0 flex-1 text-sm">
          <b>Connection lost.</b> Reconnecting… What you see may be out of date. Recording continues
          in the cloud.
        </span>
        <span className="font-mono text-xs opacity-75">
          retry in 0:{String(left).padStart(2, "0")}
        </span>
        <button
          type="button"
          onClick={retry}
          className="min-h-9 rounded-[10px] bg-white px-3 text-sm font-semibold text-[#15122B]"
        >
          Retry now
        </button>
      </div>
    </div>
  );
}

type AppStatus = { maintenance: { active: boolean; eta: string | null } };

/** Paths that stay reachable during maintenance (admins work; status explains). */
function bypassesMaintenance(path: string) {
  return path.startsWith("/admin") || path === "/status";
}

/**
 * Shows the maintenance page on every route while the admin runtime setting
 * `maintenance_active` is on (public `/v1/app/status`, polled every minute).
 */
export function MaintenanceGate({ children }: { children: ReactNode }) {
  const path = useRouterState({ select: (state) => state.location.pathname });
  const query = useQuery({
    queryKey: ["app-status"],
    queryFn: () =>
      apiClient.get<AppStatus>("/v1/app/status", { skipAuth: true, skipAuthRefresh: true }),
    enabled: !isDemoMode,
    refetchInterval: 60_000,
    retry: false,
    staleTime: 30_000,
  });
  if (query.data?.maintenance?.active && !bypassesMaintenance(path)) {
    return (
      <MaintenanceScreen
        eta={query.data.maintenance.eta}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }
  return children;
}

export { useCountdown, useOnline, OFFLINE_RETRY_SECONDS };
