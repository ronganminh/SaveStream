import { Link, useNavigate, useRouterState } from "@tanstack/react-router";
import { useEffect, useMemo, useState, type ElementType, type ReactNode } from "react";
import {
  Activity,
  AlertTriangle,
  Info,
  Bell,
  Check,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  CircleHelp,
  Clock3,
  Cloud,
  CreditCard,
  Download,
  ExternalLink,
  FileVideo,
  Gauge,
  Globe2,
  HardDrive,
  Languages,
  LayoutDashboard,
  Menu,
  Monitor,
  MonitorCog,
  Moon,
  MoreHorizontal,
  Pause,
  Plus,
  Radio,
  Search,
  Settings,
  ShieldCheck,
  Sparkles,
  Sun,
  Trash2,
  UserRound,
  Users,
  Video,
  X,
  Zap,
} from "lucide-react";
import { Button, buttonVariants } from "@/components/ui/button";
import { toast } from "sonner";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import { notificationStore, useNotifications } from "@/lib/notification-store";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";
import {
  channelLookupExamples,
  usage,
  user,
  type Notification,
  type Status,
} from "@/mocks/fixtures";
import { usePreferences, type ThemePreference } from "@/lib/preferences";
import {
  isDemoMode,
  isProductionMode,
  productionBackendConnected,
} from "@/lib/app-config";
import { useAuth } from "@/auth/auth-context";
import { meta, publicMeta } from "@/lib/route-metadata";
import { planCatalog } from "@/lib/plan-catalog";
import { formatDate } from "@/lib/formatters";
import type { ChannelModel, RecordingModel } from "@/repositories";
import {
  useActiveRecordingData,
  useChannelsData,
  useRecordingsData,
} from "@/hooks/use-domain-data";
import {
  channelActionErrorMessage,
  existingWatchId,
  useCreateChannelMutation,
  useDeleteChannelMutation,
  usePauseChannelMutation,
  useResumeChannelMutation,
  watchQuotaLimit,
} from "@/hooks/use-channel-mutations";
import {
  displayNameFromTikTokUsername,
  parseTikTokSource,
} from "@/lib/tiktok-source";
import {
  artifactActionErrorMessage,
  recordingActionErrorMessage,
  useDeleteRecordingMutation,
  useRecordingDownloadMutation,
} from "@/hooks/use-recording-mutations";

export { meta, publicMeta };
const mainNav = [
  { to: "/overview", label: "Overview", icon: LayoutDashboard },
  { to: "/channels", label: "Channels", icon: Radio },
  { to: "/recordings", label: "Recordings", icon: FileVideo },
  { to: "/usage", label: "Usage & Billing", icon: Gauge },
] as const;
const adminNav = [
  { to: "/admin/system", label: "System", icon: Activity },
  { to: "/admin/workers", label: "Workers", icon: MonitorCog },
  { to: "/admin/jobs", label: "Jobs", icon: Zap },
  { to: "/admin/errors", label: "Errors", icon: AlertTriangle },
] as const;

function useShellAccount() {
  const { user: authUser } = useAuth();
  if (isDemoMode || !authUser) {
    return {
      name: user.name,
      email: user.email,
      initials: user.initials,
      subLabel: `${user.plan} plan`,
    };
  }

  const name = authUser.display_name?.trim() || authUser.email.split("@")[0] || authUser.email;
  const initials = name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("") || authUser.email[0]?.toUpperCase() || "U";

  return {
    name,
    email: authUser.email,
    initials,
    subLabel: authUser.role === "admin" ? "Admin account" : "Account",
  };
}
export function Logo({ compact = false }: { compact?: boolean }) {
  const { t } = usePreferences();
  return (
    <Link
      to="/"
      aria-label={`SaveStream · ${t("Go home")}`}
      className="flex min-w-0 items-center gap-2.5 font-semibold"
    >
      <img src="/savestream-mark.svg" alt="" className="size-8 shrink-0" width="32" height="32" />
      {!compact && <span className="truncate">SaveStream</span>}
    </Link>
  );
}
export function CreatorAvatar({
  channel,
  size = "md",
}: {
  channel: ChannelModel;
  size?: "sm" | "md" | "lg";
}) {
  return (
    <div
      className={cn(
        "grid shrink-0 place-items-center rounded-full bg-gradient-to-br font-semibold text-avatar-foreground",
        channel.tone,
        size === "sm"
          ? "size-8 text-[10px]"
          : size === "lg"
            ? "size-14 text-sm"
            : "size-10 text-xs",
      )}
    >
      {channel.initials}
    </div>
  );
}
export function PlatformBadge({ soon = false }: { soon?: boolean }) {
  const { t } = usePreferences();
  return (
    <span className="inline-flex items-center gap-1 rounded-md border bg-surface-subtle px-1.5 py-0.5 text-[11px] font-medium text-muted-foreground">
      <span className="font-bold text-foreground">♪</span>
      {soon ? `Douyin · ${t("Coming soon")}` : "TikTok"}
    </span>
  );
}
const statusStyles: Record<Status, string> = {
  Recording: "border-recording/20 bg-recording-subtle text-recording",
  Processing: "border-info/20 bg-info-subtle text-info",
  Ready: "border-success/20 bg-success-subtle text-success",
  Waiting: "border-warning/20 bg-warning-subtle text-warning-foreground",
  Offline: "border-border bg-muted text-muted-foreground",
  Paused: "border-border bg-muted text-muted-foreground",
  Error: "border-recording/20 bg-recording-subtle text-recording",
};
export function StatusBadge({ status, pulse = false }: { status: Status; pulse?: boolean }) {
  const { t } = usePreferences();
  const icon =
    status === "Ready" ? (
      <Check className="size-3" />
    ) : status === "Processing" ? (
      <span className="size-3 animate-spin rounded-full border border-current border-t-transparent" />
    ) : status === "Paused" ? (
      <Pause className="size-3" />
    ) : status === "Error" ? (
      <AlertTriangle className="size-3" />
    ) : (
      <span
        className={cn(
          "size-1.5 rounded-full bg-current",
          (pulse || status === "Recording") && "animate-pulse",
        )}
      />
    );
  return (
    <span
      className={cn(
        "inline-flex h-6 items-center gap-1.5 rounded-md border px-2 text-xs font-medium",
        statusStyles[status],
      )}
    >
      {icon}
      {t(status)}
    </span>
  );
}
export function UsageProgress({
  value,
  label,
  tone = "primary",
}: {
  value: number;
  label?: string;
  tone?: "primary" | "warning";
}) {
  return (
    <div>
      <div
        role="progressbar"
        aria-label={label ?? "Progress"}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={Math.min(Math.max(value, 0), 100)}
        className="h-1.5 overflow-hidden rounded-full bg-muted"
      >
        <div
          className={cn("h-full rounded-full", tone === "warning" ? "bg-warning" : "bg-primary")}
          style={{ width: `${Math.min(value, 100)}%` }}
        />
      </div>
      {label && <p className="mt-1.5 text-xs text-muted-foreground">{label}</p>}
    </div>
  );
}
export function StatCard({
  label,
  value,
  detail,
  icon: Icon,
  progress,
}: {
  label: string;
  value: string;
  detail: string;
  icon: ElementType;
  progress?: number;
}) {
  const { t } = usePreferences();
  return (
    <div className="border-r border-b bg-surface p-4 last:border-r-0 sm:p-5">
      <div className="flex items-center justify-between text-sm text-muted-foreground">
        <span>{t(label)}</span>
        <Icon className="size-4" />
      </div>
      <div className="mt-3 font-mono text-2xl font-semibold tracking-normal text-foreground">
        {value}
      </div>
      <div className="mt-1 text-xs text-muted-foreground">{t(detail)}</div>
      {progress !== undefined && (
        <div className="mt-4">
          <UsageProgress value={progress} />
        </div>
      )}
    </div>
  );
}
export function PageHeader({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle?: string;
  action?: ReactNode;
}) {
  const { t } = usePreferences();
  return (
    <header className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
      <div>
        <h1 className="text-2xl font-semibold tracking-normal">{t(title)}</h1>
        {subtitle && <p className="mt-1 max-w-2xl text-sm text-muted-foreground">{t(subtitle)}</p>}
      </div>
      {action}
    </header>
  );
}

const themeOptions: { value: ThemePreference; label: string; icon: typeof Sun }[] = [
  { value: "light", label: "Light", icon: Sun },
  { value: "dark", label: "Dark", icon: Moon },
  { value: "system", label: "System", icon: Monitor },
];
export function ThemeMenu({ full = false }: { full?: boolean }) {
  const { theme, setTheme, t } = usePreferences();
  const current = themeOptions.find((option) => option.value === theme);
  const CurrentIcon = current?.icon ?? Monitor;
  const currentLabel = current?.label ?? "System";
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          size={full ? "default" : "icon"}
          className={cn(full && "w-full justify-start")}
          aria-label={`${t("Theme")}: ${t(currentLabel)}`}
        >
          <CurrentIcon />
          {full && <span>{t(currentLabel)}</span>}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuLabel>{t("Theme")}</DropdownMenuLabel>
        {themeOptions.map(({ value, label, icon: Icon }) => (
          <DropdownMenuItem key={value} onSelect={() => setTheme(value)}>
            <Icon />
            <span className="flex-1">{t(label)}</span>
            {theme === value && <Check className="size-4" />}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
export function LanguageMenu({ full = false }: { full?: boolean }) {
  const { language, setLanguage, t } = usePreferences();
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          size={full ? "default" : "icon"}
          className={cn(full && "w-full justify-start")}
          aria-label={`${t("Language")}: ${language.toUpperCase()}`}
        >
          <Languages />
          {full && <span>{language.toUpperCase()}</span>}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuLabel>{t("Language")}</DropdownMenuLabel>
        <DropdownMenuItem onSelect={() => setLanguage("en")}>
          <Globe2 />
          <span className="flex-1">English</span>
          <span className="text-xs text-muted-foreground">EN</span>
          {language === "en" && <Check className="size-4" />}
        </DropdownMenuItem>
        <DropdownMenuItem onSelect={() => setLanguage("vi")}>
          <Globe2 />
          <span className="flex-1">Tiếng Việt</span>
          <span className="text-xs text-muted-foreground">VI</span>
          {language === "vi" && <Check className="size-4" />}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
export function AppSidebar({ open, onClose }: { open: boolean; onClose: () => void }) {
  const path = useRouterState({ select: (s) => s.location.pathname });
  const { t } = usePreferences();
  const { identity } = useAuth();
  const account = useShellAccount();
  const canSeeAdmin = identity.role === "admin";
  const item = (
    it:
      | (typeof mainNav)[number]
      | (typeof adminNav)[number]
      | { to: "/notifications" | "/settings" | "/help"; label: string; icon: ElementType },
  ) => (
    <Link
      key={it.to}
      to={it.to}
      onClick={onClose}
      className={cn(
        "flex h-9 items-center gap-3 rounded-md px-3 text-sm font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
        (path === it.to ||
          path.startsWith(it.to + "/") ||
          (it.to === "/usage" && path.startsWith("/billing"))) &&
          "bg-accent text-foreground",
      )}
    >
      <it.icon className="size-4" />
      <span>{t(it.label)}</span>
    </Link>
  );
  return (
    <>
      <button
        type="button"
        aria-label={t("Close menu")}
        onClick={onClose}
        className={cn(
          "fixed inset-0 z-[var(--z-drawer-overlay)] bg-overlay lg:hidden",
          open ? "block" : "hidden",
        )}
      />
      <aside
        aria-label={t("Main navigation")}
        className={cn(
          "fixed inset-y-0 left-0 z-[var(--z-drawer)] flex w-64 flex-col border-r bg-sidebar transition-transform lg:translate-x-0",
          open ? "translate-x-0" : "-translate-x-full",
        )}
      >
        <div className="flex h-16 items-center justify-between px-5">
          <Logo />
          <Button
            variant="ghost"
            size="icon"
            className="lg:hidden"
            onClick={onClose}
            aria-label={t("Close menu")}
          >
            <X />
          </Button>
        </div>
        <nav className="flex-1 space-y-6 overflow-y-auto px-3 py-3">
          <div className="space-y-1">{mainNav.map(item)}</div>
          <div>
            <p className="mb-2 px-3 text-[10px] font-semibold uppercase text-muted-foreground">
              {t("Workspace")}
            </p>
            {item({ to: "/notifications", label: "Notifications", icon: Bell })}
            {item({ to: "/settings", label: "Settings", icon: Settings })}
            {item({ to: "/help", label: "Help", icon: CircleHelp })}
          </div>
          {canSeeAdmin && (
            <div className="border-t pt-5">
              <p className="mb-2 flex items-center gap-2 px-3 text-[10px] font-semibold uppercase text-muted-foreground">
                <ShieldCheck className="size-3" />
                {t("Admin")}
              </p>
              {adminNav.map(item)}
            </div>
          )}
        </nav>
        <div className="border-t p-3">
          <div className="mb-2 grid grid-cols-2 gap-1 lg:hidden">
            <LanguageMenu full />
            <ThemeMenu full />
          </div>
          <Link
            to="/settings/account"
            onClick={onClose}
            className="flex items-center gap-3 rounded-md p-2 hover:bg-accent"
          >
            <span className="grid size-8 place-items-center rounded-full bg-primary text-xs font-semibold text-primary-foreground">
              {account.initials}
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium">{account.name}</p>
              <p className="text-xs text-muted-foreground">{account.subLabel}</p>
            </div>
            <ChevronRight className="size-4 text-muted-foreground" />
          </Link>
        </div>
      </aside>
    </>
  );
}
export function AppTopbar({ onMenu }: { onMenu: () => void }) {
  const [cmd, setCmd] = useState(false);
  const navigate = useNavigate();
  const { t } = usePreferences();
  const { signOut } = useAuth();
  const account = useShellAccount();
  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setCmd((o) => !o);
      }
    };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, []);
  const list = useNotifications();
  const unread = list.filter((n) => !n.read).length;
  return (
    <div className="sticky top-0 z-[var(--z-sticky)] flex h-16 items-center gap-2 border-b bg-background/95 px-3 backdrop-blur sm:px-4 lg:px-6">
      <Button
        variant="ghost"
        size="icon"
        onClick={onMenu}
        className="lg:hidden"
        aria-label={t("Open menu")}
      >
        <Menu />
      </Button>
      <button
        type="button"
        onClick={() => setCmd(true)}
        className="relative hidden h-9 max-w-md flex-1 items-center rounded-md border bg-surface-subtle pl-9 pr-14 text-left text-sm text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring md:flex"
      >
        <Search className="absolute left-3 top-2.5 size-4" />
        {t("Search channels or recordings")}
        <kbd className="absolute right-2 top-2 rounded border bg-background px-1.5 py-0.5 text-[10px]">
          ⌘ K
        </kbd>
      </button>
      <div className="ml-auto flex min-w-0 items-center gap-0.5 sm:gap-1">
        {isDemoMode && (
          <span
            className="mr-0.5 inline-flex shrink-0 items-center rounded-md border border-warning/30 bg-warning-subtle px-1.5 py-1 text-[10px] font-semibold text-warning-foreground sm:px-2"
            aria-label={t("Demo — illustrative data")}
          >
            <span className="sm:hidden">{t("Demo")}</span>
            <span className="hidden sm:inline">{t("Demo — illustrative data")}</span>
          </span>
        )}
        <Button
          variant="ghost"
          size="icon"
          className="md:hidden"
          aria-label={t("Search")}
          onClick={() => setCmd(true)}
        >
          <Search />
        </Button>
        <LanguageMenu />
        <ThemeMenu />
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              size="icon"
              className="relative"
              aria-label={unread ? `${t("Notifications")}, ${unread} unread` : t("Notifications")}
            >
              <Bell />
              {unread > 0 && (
                <span className="absolute right-1 top-1 grid h-4 min-w-4 place-items-center rounded-full bg-destructive px-1 font-mono text-[9px] font-semibold text-destructive-foreground">
                  {unread}
                </span>
              )}
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-[min(360px,calc(100vw-2rem))] p-0">
            <div className="flex items-center justify-between border-b px-4 py-3">
              <p className="font-medium">{t("Notifications")}</p>
              <button
                type="button"
                disabled={!unread}
                onClick={() => notificationStore.markAllRead()}
                className="text-xs font-medium text-primary disabled:text-muted-foreground"
              >
                {t("Mark all read")}
              </button>
            </div>
            {list.length ? (
              <div className="max-h-96 overflow-y-auto">
                {list.map((n) => (
                  <NotificationItem key={n.id} notification={n} />
                ))}
              </div>
            ) : (
              <p className="p-6 text-center text-sm text-muted-foreground">
                {t("You’re all caught up.")}
              </p>
            )}
            <Link
              to="/notifications"
              className="block border-t p-3 text-center text-xs font-medium text-primary"
            >
              {t("View all notifications")}
            </Link>
          </DropdownMenuContent>
        </DropdownMenu>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              className="ml-0.5 h-9 px-1.5 sm:ml-1 sm:px-2"
              aria-label={t("Account menu")}
            >
              <span className="grid size-7 place-items-center rounded-full bg-primary text-[10px] font-semibold text-primary-foreground">
                {account.initials}
              </span>
              <ChevronDown className="hidden size-3 sm:block" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuLabel className="font-normal">
              <p className="text-sm font-medium">{account.name}</p>
              <p className="text-xs text-muted-foreground">{account.email}</p>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={() => navigate({ to: "/settings/account" })}>
              <UserRound />
              {t("Account")}
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => navigate({ to: "/billing" })}>
              <CreditCard />
              {t("Billing")}
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => navigate({ to: "/notifications" })}>
              <Bell />
              {t("Notifications")}
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem
              onSelect={(event) => {
                event.preventDefault();
                void signOut().finally(() => navigate({ to: "/sign-in" }));
              }}
            >
              {t("Sign out")}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
      <CommandSearch open={cmd} onOpenChange={setCmd} />
    </div>
  );
}
export function AppShell({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const path = useRouterState({ select: (s) => s.location.pathname });
  const { t } = usePreferences();

  if (isProductionMode && !productionBackendConnected) {
    return (
      <div className="grid min-h-screen place-items-center bg-background px-4">
        <div className="max-w-lg rounded-xl border bg-surface p-8 text-center shadow-dashboard">
          <div className="mx-auto w-fit"><Logo /></div>
          <h1 className="mt-6 text-2xl font-semibold">{t("Backend not connected")}</h1>
          <p className="mt-3 text-sm leading-6 text-muted-foreground">
            {t("This screen is unavailable in production until authentication and API services are connected.")}
          </p>
          <Button asChild className="mt-6">
            <Link to="/sign-in">{t("Back to sign in")}</Link>
          </Button>
        </div>
      </div>
    );
  }

  return (
    <TooltipProvider>
      <div className="min-h-screen bg-background">
        <AppSidebar open={open} onClose={() => setOpen(false)} />
        <div className="lg:pl-64">
          <AppTopbar onMenu={() => setOpen(true)} />
          <main className="mx-auto min-w-0 max-w-[1440px] overflow-x-clip p-4 pb-24 sm:p-6 lg:p-8">{children}</main>
          <nav
            aria-label={t("Primary")}
            className="fixed inset-x-0 bottom-0 z-[var(--z-sticky)] grid grid-cols-3 border-t bg-background px-1 pt-1 pb-[max(.25rem,env(safe-area-inset-bottom))] lg:hidden"
          >
            {mainNav.slice(0, 3).map((i) => (
              <Link
                key={i.to}
                to={i.to}
                className={cn(
                  "flex flex-col items-center gap-1 rounded-md py-2 text-[10px] text-muted-foreground",
                  path.startsWith(i.to) && "text-foreground font-medium",
                )}
              >
                <i.icon className="size-4" />
                {t(i.label)}
              </Link>
            ))}
          </nav>
        </div>
      </div>
    </TooltipProvider>
  );
}
export function ActiveRecordingCard({ empty = false }: { empty?: boolean }) {
  const { t } = usePreferences();
  const { query: channelsQuery } = useChannelsData();
  const { query: activeQuery, state: activeState } = useActiveRecordingData();
  const recording = activeQuery.data;

  if (empty || activeState.kind === "empty")
    return (
      <section className="border-y bg-surface px-5 py-8">
        <div className="flex items-start gap-4">
          <span className="grid size-10 place-items-center rounded-full bg-muted">
            <Radio className="size-4 text-muted-foreground" />
          </span>
          <div>
            <h2 className="font-semibold">{t("No active recordings")}</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              {t(
                "We’re monitoring your enabled channels. Recording will start automatically when one goes live.",
              )}
            </p>
          </div>
        </div>
      </section>
    );

  if (activeState.kind === "loading") {
    return <div className="h-44 animate-pulse rounded-lg border bg-muted" aria-busy="true" />;
  }

  if (activeState.kind === "error" || !recording) {
    return null;
  }

  const channel = channelsQuery.data?.find((item) => item.id === recording.channelId);
  return (
    <section className="overflow-hidden rounded-lg border border-recording/25 bg-surface">
      <div className="flex items-center justify-between border-b border-recording/15 bg-recording-subtle px-5 py-3">
        <div className="flex items-center gap-2 text-xs font-semibold uppercase text-recording">
          <span className="size-2 animate-pulse rounded-full bg-recording" />
          {t("Active recording")}
        </div>
        <StatusBadge status={recording.status} />
      </div>
      <div className="grid gap-6 p-5 md:grid-cols-[1fr_auto] md:items-center">
        <div className="flex items-center gap-4">
          {channel ? (
            <CreatorAvatar channel={channel} size="lg" />
          ) : (
            <span className="grid size-12 place-items-center rounded-full bg-primary-subtle text-sm font-semibold text-primary">
              {recording.handle.replace(/^@/, "").slice(0, 2).toUpperCase()}
            </span>
          )}
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-lg font-semibold">{channel?.name ?? recording.handle}</h2>
              <PlatformBadge />
            </div>
            <p className="mt-0.5 text-sm text-muted-foreground">{recording.handle}</p>
            <p className="mt-3 flex items-center gap-2 text-xs text-muted-foreground">
              <Cloud className="size-4 text-success" />
              {t("Recording runs on our servers. You can safely close this page.")}
            </p>
          </div>
        </div>
        <div className="grid grid-cols-2 gap-x-8 gap-y-3 md:text-right">
          <div>
            <p className="text-xs text-muted-foreground">{t("Elapsed")}</p>
            <p className="font-mono text-2xl font-semibold">{recording.duration}</p>
          </div>
          <div>
            <p className="text-xs text-muted-foreground">{t("Written")}</p>
            <p className="font-mono text-lg font-medium">{recording.size}</p>
          </div>
          <div>
            <p className="text-xs text-muted-foreground">{t("Started")}</p>
            <p className="text-sm font-medium">
              {recording.date} · {recording.time}
            </p>
          </div>
          <Button asChild size="sm">
            <Link to="/recordings/$id" params={{ id: recording.id }}>
              {t("View recording")}
              <ChevronRight />
            </Link>
          </Button>
        </div>
      </div>
    </section>
  );
}
export function SearchInput({
  value,
  onChange,
  placeholder = "Search",
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  const { t } = usePreferences();
  return (
    <div className="relative">
      <Search className="absolute left-3 top-2.5 size-4 text-muted-foreground" />
      <Input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="pl-9"
        placeholder={t(placeholder)}
        aria-label={t(placeholder)}
      />
    </div>
  );
}
export function FilterBar({ children }: { children: ReactNode }) {
  return (
    <div className="mb-4 flex flex-col gap-2 border-y bg-surface-subtle p-2.5 sm:flex-row sm:items-center">
      {children}
    </div>
  );
}
export function ChannelRow({ channel }: { channel: ChannelModel }) {
  const c = useChannelControls(channel);
  if (c.removed) return null;
  return (
    <div className="grid grid-cols-[1.5fr_.7fr_.7fr_.8fr_.6fr_auto] items-center gap-4 border-b px-4 py-3 text-sm last:border-b-0">
      <Link to="/channels/$id" params={{ id: channel.id }} className="flex items-center gap-3">
        <CreatorAvatar channel={channel} />
        <span>
          <b className="block font-medium">{channel.name}</b>
          <small className="text-muted-foreground">{channel.handle}</small>
        </span>
      </Link>
      <PlatformBadge />
      <Tooltip>
        <TooltipTrigger asChild>
          <div className="w-fit">
            <Switch
              checked={c.on}
              onCheckedChange={c.toggle}
              aria-label={`Monitoring for ${channel.handle}`}
            />
          </div>
        </TooltipTrigger>
        <TooltipContent>
          When monitoring is on, we’ll automatically record the next livestream.
        </TooltipContent>
      </Tooltip>
      <StatusBadge status={c.on ? channel.status : "Paused"} />
      <span className="text-muted-foreground">{channel.checked}</span>
      <MoreMenu channel={channel} controls={c} />
      {c.dialogs}
    </div>
  );
}
export function ChannelCard({ channel }: { channel: ChannelModel }) {
  const c = useChannelControls(channel);
  const { t } = usePreferences();
  if (c.removed) return null;
  return (
    <div className="rounded-lg border bg-surface p-4">
      <div className="flex items-start">
        <CreatorAvatar channel={channel} />
        <div className="ml-3">
          <p className="font-medium">{channel.name}</p>
          <p className="text-xs text-muted-foreground">{channel.handle}</p>
        </div>
        <div className="ml-auto">
          <MoreMenu channel={channel} controls={c} />
        </div>
      </div>
      <div className="mt-4 flex items-center justify-between">
        <StatusBadge status={c.on ? channel.status : "Paused"} />
        <label className="flex items-center gap-2 text-xs text-muted-foreground">
          {t("Monitoring")} <Switch checked={c.on} onCheckedChange={c.toggle} />
        </label>
      </div>
      <div className="mt-4 flex justify-between border-t pt-3 text-xs">
        <span className="text-muted-foreground">
          {channel.live} · {channel.recordings} recordings
        </span>
        <Link to="/channels/$id" params={{ id: channel.id }} className="font-medium text-primary">
          {t("View")}
        </Link>
      </div>
      {c.dialogs}
    </div>
  );
}
function MoreMenu({
  channel,
  controls,
}: {
  channel: ChannelModel;
  controls: ReturnType<typeof useChannelControls>;
}) {
  const navigate = useNavigate();
  const { t } = usePreferences();
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" aria-label={`${t("More actions")}: ${channel.handle}`}>
          <MoreHorizontal />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem
          onSelect={() => navigate({ to: "/channels/$id", params: { id: channel.id } })}
        >
          <ExternalLink />
          {t("View channel")}
        </DropdownMenuItem>
        {controls.on ? (
          <DropdownMenuItem onSelect={() => controls.openPause()}>
            <Pause />
            {t("Pause monitoring")}
          </DropdownMenuItem>
        ) : (
          <DropdownMenuItem onSelect={() => controls.toggle(true)}>
            <Radio />
            {t("Resume monitoring")}
          </DropdownMenuItem>
        )}
        <DropdownMenuSeparator />
        <DropdownMenuItem className="text-destructive" onSelect={() => controls.openRemove()}>
          <Trash2 />
          {t("Remove channel")}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
export function RecordingThumb({ recording }: { recording: RecordingModel }) {
  return (
    <div
      className={cn(
        "relative aspect-video w-24 shrink-0 overflow-hidden rounded-md",
        recording.color,
      )}
    >
      <div className="absolute inset-0 bg-thumbnail-grid" />
      <span className="absolute bottom-1 right-1 rounded bg-player-overlay px-1 font-mono text-[9px] text-player-foreground">
        {recording.duration}
      </span>
      <Video className="absolute left-2 top-2 size-4 text-player-foreground/70" />
    </div>
  );
}
export function RecordingRow({ recording }: { recording: RecordingModel }) {
  return (
    <div className="grid grid-cols-[1.7fr_1fr_.7fr_.7fr_.8fr_.7fr_auto] items-center gap-4 border-b px-4 py-3 text-sm last:border-0">
      <Link to="/recordings/$id" params={{ id: recording.id }} className="flex items-center gap-3">
        <RecordingThumb recording={recording} />
        <span>
          <b className="block font-medium">
            {recording.handle} — {recording.title}
          </b>
          <small className="text-muted-foreground">
            {recording.date} · {recording.time}
          </small>
        </span>
      </Link>
      <Link to="/channels/$id" params={{ id: recording.channelId }} className="hover:underline">
        {recording.handle}
      </Link>
      <span className="font-mono">{recording.duration}</span>
      <span className="font-mono">{recording.size}</span>
      <ExpiryText recording={recording} />
      <StatusBadge status={recording.status} />
      <RecordingActions recording={recording} />
    </div>
  );
}
export function RecordingCard({ recording }: { recording: RecordingModel }) {
  return (
    <div className="overflow-hidden rounded-lg border bg-surface">
      <Link
        to="/recordings/$id"
        params={{ id: recording.id }}
        aria-label={`${recording.handle} — ${recording.title}`}
      >
        <div className={cn("relative aspect-video", recording.color)}>
          <div className="absolute inset-0 bg-thumbnail-grid" />
          <div className="absolute inset-x-3 bottom-3 flex justify-between">
            <StatusBadge status={recording.status} />
            <span className="rounded bg-player-overlay px-1.5 py-0.5 font-mono text-[10px] text-player-foreground">
              {recording.duration}
            </span>
          </div>
        </div>
      </Link>
      <div className="p-4">
        <div className="flex">
          <div className="min-w-0">
            <p className="truncate text-sm font-medium">
              {recording.handle} — {recording.title}
            </p>
            <p className="mt-1 text-xs text-muted-foreground">
              {recording.date} · {recording.time} · {recording.size}
            </p>
          </div>
          <div className="ml-auto">
            <RecordingActions recording={recording} />
          </div>
        </div>
        <p className="mt-3 text-xs">
          <ExpiryText recording={recording} prefix />
        </p>
      </div>
    </div>
  );
}
function RecordingActions({ recording }: { recording: RecordingModel }) {
  const navigate = useNavigate();
  const [del, setDel] = useState(false);
  const { t } = usePreferences();
  const downloadRecording = useRecordingDownloadMutation();
  const deleteRecording = useDeleteRecordingMutation();

  const download = () => {
    if (isDemoMode) {
      toast.success("Download started", {
        description: `${recording.size} · ${recording.handle} — ${recording.title}`,
      });
      return;
    }

    void downloadRecording
      .mutateAsync(recording.id)
      .then(({ download: signed }) => window.location.assign(signed.url))
      .catch((error) =>
        toast.error("Download unavailable", {
          description: artifactActionErrorMessage(error),
        }),
      );
  };

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            variant="ghost"
            size="icon"
            aria-label={`${t("More actions")}: ${recording.title}`}
          >
            <MoreHorizontal />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem
            onSelect={() => navigate({ to: "/recordings/$id", params: { id: recording.id } })}
          >
            <ExternalLink />
            {t("View recording")}
          </DropdownMenuItem>
          <DropdownMenuItem
            disabled={recording.status !== "Ready" || downloadRecording.isPending}
            onSelect={download}
          >
            <Download />
            {downloadRecording.isPending ? t("Preparing…") : t("Download")}
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem
            disabled={!recording.actions.can_delete || deleteRecording.isPending}
            className="text-destructive"
            onSelect={() => setDel(true)}
          >
            <Trash2 />
            {t("Delete")}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
      {isDemoMode ? (
        <ConfirmDeleteDialog open={del} onOpenChange={setDel} onDeleted={() => {}} />
      ) : (
        <ConfirmDialog
          destructive
          open={del}
          onOpenChange={setDel}
          title="Delete recording?"
          body="This recording will disappear from your library and its stored artifact will be scheduled for cleanup."
          confirmLabel="Delete recording"
          confirmDisabled={deleteRecording.isPending}
          onConfirm={() => {
            void deleteRecording
              .mutateAsync(recording.id)
              .then(() => {
                setDel(false);
                toast.success("Recording deleted");
              })
              .catch((error) => {
                toast.error("Could not delete recording", {
                  description: recordingActionErrorMessage(error),
                });
              });
          }}
        />
      )}
    </>
  );
}

export function VideoPlayerShell({
  state = "ready",
}: {
  state?: "ready" | "active" | "processing" | "failed";
}) {
  const { t } = usePreferences();
  return (
    <div className="relative grid aspect-video max-h-[620px] w-full place-items-center overflow-hidden rounded-lg bg-player text-player-foreground">
      <div className="absolute inset-0 bg-player-grid" />
      {state === "ready" && (
        <button
          aria-label={t("Play video")}
          className="relative grid size-16 place-items-center rounded-full bg-player-foreground text-player"
        >
          <span className="ml-1 text-2xl">▶</span>
        </button>
      )}
      {state === "active" && (
        <div className="relative text-center">
          <StatusBadge status="Recording" />
          <p className="mt-5 font-mono text-4xl font-semibold">01:42:18</p>
          <p className="mt-2 text-sm text-player-muted">
            Playback will be available after the livestream ends.
          </p>
        </div>
      )}
      {state === "processing" && (
        <div className="relative text-center">
          <span className="mx-auto block size-8 animate-spin rounded-full border-2 border-player-muted border-t-player-foreground" />
          <p className="mt-5 font-medium">Finalizing your recording</p>
          <p className="mt-2 text-sm text-player-muted">
            Playback will be available when processing is complete.
          </p>
        </div>
      )}
      {state === "failed" && (
        <div className="relative max-w-md text-center">
          <AlertTriangle className="mx-auto size-8 text-recording" />
          <p className="mt-4 font-medium">Recording couldn’t be completed</p>
          <p className="mt-2 text-sm text-player-muted">
            47 minutes were saved before the stream connection was lost.
          </p>
        </div>
      )}
    </div>
  );
}
export function AddChannelDialog({ trigger }: { trigger?: ReactNode }) {
  const navigate = useNavigate();
  const { t } = usePreferences();
  const { query: channelsQuery } = useChannelsData();
  const createChannel = useCreateChannelMutation();
  const [open, setOpen] = useState(false);
  const [input, setInput] = useState("");
  const [state, setState] = useState<LookupState>("idle");
  const [phase, setPhase] = useState<"form" | "submitting" | "success">("form");
  const [createdWatchId, setCreatedWatchId] = useState<string | null>(null);
  const [duplicateWatchId, setDuplicateWatchId] = useState<string | null>(null);
  const [quotaLimit, setQuotaLimit] = useState<number | null>(null);
  const [errorText, setErrorText] = useState<string | null>(null);
  const parsed = useMemo(() => parseTikTokSource(input), [input]);
  const handle = parsed?.handle ?? null;
  const name = parsed ? displayNameFromTikTokUsername(parsed.username) : "";
  const channelItems = channelsQuery.data ?? [];

  useEffect(() => {
    setErrorText(null);
    setQuotaLimit(null);
    setDuplicateWatchId(null);
    if (!input.trim()) {
      setState("idle");
      return;
    }
    if (!parsed) {
      setState("invalid");
      return;
    }
    const existing = channelItems.find(
      (channel) => channel.handle.toLowerCase() === parsed.handle.toLowerCase(),
    );
    if (existing) {
      setDuplicateWatchId(existing.id);
      setState("exists");
      return;
    }
    setState("found");
  }, [channelItems, input, parsed]);

  const reset = () => {
    setInput("");
    setState("idle");
    setPhase("form");
    setCreatedWatchId(null);
    setDuplicateWatchId(null);
    setQuotaLimit(null);
    setErrorText(null);
  };

  const submit = async () => {
    if (state !== "found" || !parsed) return;
    setPhase("submitting");
    setErrorText(null);
    try {
      const watch = await createChannel.mutateAsync({
        source: parsed.source,
        auto_record: true,
      });
      setCreatedWatchId(watch.id);
      setPhase("success");
      toast.success(`Monitoring ${parsed.handle}`, {
        description: "We’ll record automatically when this channel goes live.",
      });
    } catch (error) {
      setPhase("form");
      const duplicateId = existingWatchId(error);
      if (duplicateId) {
        setDuplicateWatchId(duplicateId);
        setState("exists");
        return;
      }
      const limit = watchQuotaLimit(error);
      if (limit !== null) {
        setQuotaLimit(limit);
        setState("limit");
        return;
      }
      setState("unavailable");
      setErrorText(channelActionErrorMessage(error));
    }
  };

  const msg: Partial<
    Record<LookupState, { tone: "error" | "warning" | "info"; title: string; body: string }>
  > = {
    invalid: {
      tone: "error",
      title: "Enter a valid TikTok username or URL",
      body: "Use @username or a link like https://www.tiktok.com/@username.",
    },
    exists: {
      tone: "info",
      title: "This channel is already monitored",
      body: "It’s in your channel list. Open it to change monitoring.",
    },
    unavailable: {
      tone: "warning",
      title: "We couldn’t add this channel",
      body: errorText ?? "SaveStream could not complete the request. Try again.",
    },
    limit: {
      tone: "warning",
      title: "Monitored channel limit reached",
      body: `Your account allows ${quotaLimit ?? usage.channels.limit} monitored channels. Remove one or review billing before adding another.`,
    },
  };
  const message = msg[state];

  return (
    <Dialog
      open={open}
      onOpenChange={(nextOpen) => {
        setOpen(nextOpen);
        if (!nextOpen) setTimeout(reset, 200);
      }}
    >
      <DialogTrigger asChild>
        {trigger || (
          <Button>
            <Plus />
            {t("Add channel")}
          </Button>
        )}
      </DialogTrigger>
      <DialogContent className="inset-0 top-0 h-dvh max-w-none translate-x-0 translate-y-0 content-start overflow-y-auto rounded-none sm:inset-auto sm:left-[50%] sm:top-[50%] sm:h-auto sm:max-w-lg sm:translate-x-[-50%] sm:translate-y-[-50%] sm:rounded-lg">
        {phase === "success" ? (
          <div className="py-4 text-center">
            <span className="mx-auto grid size-12 place-items-center rounded-full bg-success-subtle text-success">
              <CheckCircle2 className="size-6" />
            </span>
            <DialogTitle className="mt-5">{t("Monitoring started")}</DialogTitle>
            <DialogDescription className="mt-2">
              {handle} is now monitored. Recording starts automatically on our servers when the
              channel goes live.
            </DialogDescription>
            <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-center">
              <Button variant="outline" onClick={reset}>
                {t("Add another")}
              </Button>
              <Button
                onClick={() => {
                  setOpen(false);
                  if (createdWatchId) {
                    void navigate({ to: "/channels/$id", params: { id: createdWatchId } });
                  } else {
                    void navigate({ to: "/channels" });
                  }
                }}
              >
                {t("View channel")}
              </Button>
            </div>
          </div>
        ) : (
          <>
            <DialogHeader>
              <DialogTitle>{t("Add TikTok channel")}</DialogTitle>
              <DialogDescription>
                Add a TikTok creator to your account. SaveStream will monitor it automatically and
                start recording when configured to do so.
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-2">
              <div>
                <label htmlFor="add-channel-input" className="mb-2 block text-sm font-medium">
                  {t("TikTok username or URL")}
                </label>
                <div className="relative">
                  <Input
                    id="add-channel-input"
                    autoFocus
                    value={input}
                    onChange={(event) => setInput(event.target.value)}
                    aria-invalid={state === "invalid"}
                    placeholder="@username or https://www.tiktok.com/@username"
                    className="pr-9"
                  />
                  {phase === "submitting" && (
                    <span
                      aria-label={t("Adding channel…")}
                      className="absolute right-3 top-2.5 size-4 animate-spin rounded-full border-2 border-muted-foreground border-t-transparent"
                    />
                  )}
                  {state === "found" && phase !== "submitting" && (
                    <Check className="absolute right-3 top-2.5 size-4 text-success" />
                  )}
                </div>
              </div>
              {state === "found" && parsed && (
                <div className="flex items-center gap-3 rounded-md border bg-surface-subtle p-3">
                  <div className="grid size-10 place-items-center rounded-full bg-primary text-xs font-semibold text-primary-foreground">
                    {name
                      .split(" ")
                      .map((word) => word[0])
                      .join("")
                      .slice(0, 2)}
                  </div>
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium">{name}</p>
                    <p className="text-xs text-muted-foreground">{parsed.handle}</p>
                  </div>
                  <div className="ml-auto">
                    <PlatformBadge />
                  </div>
                </div>
              )}
              {message && (
                <StateBanner
                  tone={message.tone}
                  title={message.title}
                  body={message.body}
                  action={
                    state === "exists" ? (
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => {
                          setOpen(false);
                          if (duplicateWatchId) {
                            void navigate({
                              to: "/channels/$id",
                              params: { id: duplicateWatchId },
                            });
                          } else {
                            void navigate({ to: "/channels" });
                          }
                        }}
                      >
                        View channel
                      </Button>
                    ) : state === "limit" ? (
                      <Button
                        size="sm"
                        onClick={() => {
                          setOpen(false);
                          void navigate({ to: "/billing" });
                        }}
                      >
                        Review billing
                      </Button>
                    ) : state === "unavailable" ? (
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => {
                          setState(parsed ? "found" : "invalid");
                          void channelsQuery.refetch();
                        }}
                      >
                        Try again
                      </Button>
                    ) : undefined
                  }
                />
              )}
              {isDemoMode && (
                <details className="rounded-md border border-dashed px-3 py-2 text-xs text-muted-foreground">
                  <summary className="cursor-pointer">Prototype: try lookup states</summary>
                  <div className="mt-2 flex flex-wrap gap-1.5">
                    {channelLookupExamples.map((example) => (
                      <button
                        type="button"
                        key={example.input}
                        onClick={() => setInput(example.input)}
                        className="rounded border bg-background px-2 py-1 font-mono hover:bg-accent"
                      >
                        {example.input}{" "}
                        <span className="font-sans text-muted-foreground">· {example.result}</span>
                      </button>
                    ))}
                  </div>
                </details>
              )}
            </div>
            <DialogFooter className="gap-2">
              <Button variant="outline" onClick={() => setOpen(false)}>
                {t("Cancel")}
              </Button>
              <Button onClick={() => void submit()} disabled={state !== "found" || phase === "submitting"}>
                {phase === "submitting" ? (
                  <>
                    <span className="size-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
                    {t("Adding")}…
                  </>
                ) : (
                  t("Add & start monitoring")
                )}
              </Button>
            </DialogFooter>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
export function UpgradeDialog({
  open,
  onOpenChange,
  fileSize = "6.2 GB",
  remaining = "2.1 GB",
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  fileSize?: string;
  remaining?: string;
}) {
  const navigate = useNavigate();
  const { t, language } = usePreferences();
  const limit = planCatalog.pro.quotas.downloadGb;
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <span className="mb-2 grid size-10 place-items-center rounded-full bg-warning-subtle text-warning-foreground">
            <Download className="size-4" />
          </span>
          <DialogTitle>{t("Not enough download quota")}</DialogTitle>
          <DialogDescription>
            {t("This demo file is larger than the remaining monthly download quota.")}{" "}
            <span className="font-mono">{fileSize}</span> / <span className="font-mono">{remaining}</span>.
            {" "}{t("Quota resets on")} {formatDate(usage.resetsOn, language)}.
          </DialogDescription>
        </DialogHeader>
        <div className="rounded-md border bg-surface-subtle p-3">
          <div className="mb-2 flex justify-between text-xs">
            <span>{t("Download bandwidth")}</span>
            <span className="font-mono text-muted-foreground">97.9 / {limit ?? "—"} GB</span>
          </div>
          <UsageProgress value={98} tone="warning" />
        </div>
        <DialogFooter className="gap-2">
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t("Cancel")}
          </Button>
          <Button
            onClick={() => {
              onOpenChange(false);
              navigate({ to: "/billing" });
            }}
          >
            {t("Upgrade plan")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
export function ConfirmDeleteDialog({
  open,
  onOpenChange,
  onDeleted,
  partial = false,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  onDeleted: () => void;
  partial?: boolean;
}) {
  return (
    <ConfirmDialog
      destructive
      open={open}
      onOpenChange={onOpenChange}
      title={partial ? "Delete partial recording?" : "Delete recording?"}
      body="This permanently removes the video from your library and cloud storage. This action cannot be undone."
      confirmLabel={partial ? "Delete partial file" : "Delete recording"}
      onConfirm={() => {
        onOpenChange(false);
        toast.success(partial ? "Partial file deleted" : "Recording deleted", {
          description: "The file was removed from cloud storage.",
        });
        onDeleted();
      }}
    />
  );
}
export function EmptyState({
  icon: Icon = FileVideo,
  title,
  body,
  action,
}: {
  icon?: ElementType;
  title: string;
  body: string;
  action?: ReactNode;
}) {
  const { t } = usePreferences();
  return (
    <div className="grid min-h-64 place-items-center border-y bg-surface-subtle px-6 py-12 text-center">
      <div>
        <span className="mx-auto grid size-10 place-items-center rounded-full border bg-background">
          <Icon className="size-4 text-muted-foreground" />
        </span>
        <h3 className="mt-4 font-medium">{t(title)}</h3>
        <p className="mx-auto mt-1 max-w-md text-sm text-muted-foreground">{t(body)}</p>
        {action && <div className="mt-5">{action}</div>}
      </div>
    </div>
  );
}
export function ErrorState({
  title = "We couldn’t load this data",
  body = "The system is retrying automatically. You don’t need to do anything.",
  onRetry,
}: {
  title?: string;
  body?: string;
  onRetry?: () => void;
}) {
  return (
    <StateBanner
      tone="warning"
      title={title}
      body={body}
      action={
        onRetry && (
          <Button size="sm" variant="outline" onClick={onRetry}>
            Retry now
          </Button>
        )
      }
    />
  );
}
export function Skeleton({ rows = 3 }: { rows?: number }) {
  return (
    <div role="status" aria-label="Loading" className="animate-pulse space-y-3">
      <div className="h-5 w-1/3 rounded bg-muted" />
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="h-16 rounded bg-muted" />
      ))}
    </div>
  );
}
export function NotificationItem({ notification: n }: { notification: Notification }) {
  const { t } = usePreferences();
  const dot =
    n.status === "Recording" || n.status === "Error"
      ? "bg-recording"
      : n.status === "Ready"
        ? "bg-success"
        : "bg-warning";
  return (
    <Link
      {...n.link}
      onClick={() => notificationStore.markRead(n.id)}
      className={cn(
        "flex gap-3 border-b p-4 text-left last:border-0 hover:bg-accent focus-visible:bg-accent focus-visible:outline-none",
        !n.read && "bg-primary-subtle/40",
      )}
    >
      <span className={cn("mt-1.5 size-2 shrink-0 rounded-full", dot)} />
      <div className="min-w-0 flex-1">
        <p className="flex items-center gap-2 text-sm font-medium">
          {t(n.title)}
          {!n.read && (
            <span className="text-[10px] font-semibold uppercase text-primary">{t("New")}</span>
          )}
        </p>
        <p className="mt-0.5 text-xs leading-5 text-muted-foreground">{n.body}</p>
        <p className="mt-1 text-[10px] text-muted-foreground">{n.time}</p>
      </div>
    </Link>
  );
}
export function PlanCard({
  name,
  price,
  current,
  features,
  suffix = "/ month",
  action,
  note,
}: {
  name: string;
  price: string;
  current?: boolean;
  features: string[];
  suffix?: string;
  action?: ReactNode;
  note?: string | undefined;
}) {
  const { t } = usePreferences();
  return (
    <div
      className={cn(
        "relative flex flex-col rounded-lg border bg-surface p-6",
        current && "border-primary ring-1 ring-primary",
      )}
    >
      {current && (
        <span className="absolute right-4 top-4 rounded-md bg-primary-subtle px-2 py-1 text-xs font-medium text-primary">
          {t("Current plan")}
        </span>
      )}
      <h3 className="text-lg font-semibold">{name}</h3>
      <p className="mt-3">
        <span className="font-mono text-3xl font-semibold">{price}</span>
        {price !== "Free" && <span className="text-sm text-muted-foreground"> {t(suffix)}</span>}
      </p>
      {note && <p className="mt-1 text-xs text-success">{note}</p>}
      <ul className="mt-6 flex-1 space-y-3">
        {features.map((f) => (
          <li key={f} className="flex gap-2 text-sm">
            <CheckCircle2 className="size-4 shrink-0 text-success" />
            {t(f)}
          </li>
        ))}
      </ul>
      {action ?? (
        <Button variant={current ? "outline" : "default"} className="mt-6 w-full" asChild>
          <Link to={current ? "/billing" : "/sign-up"}>
            {t(current ? "Manage plan" : "Choose plan")}
          </Link>
        </Button>
      )}
    </div>
  );
}
export function AdminHealthBadge({ healthy = true }: { healthy?: boolean }) {
  const { t } = usePreferences();
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 text-xs font-medium",
        healthy ? "text-success" : "text-recording",
      )}
    >
      <span className="size-1.5 rounded-full bg-current" />
      {t(healthy ? "Healthy" : "Degraded")}
    </span>
  );
}
export function JobTimeline() {
  const steps = [
    "13:22:10  Live detected",
    "13:22:13  Job queued",
    "13:22:15  Worker assigned",
    "13:22:16  Stream resolved",
    "13:22:17  Recording started",
    "15:36:41  Stream ended",
    "15:36:44  Processing started",
    "15:38:02  Uploaded",
    "15:38:03  Ready",
  ];
  return (
    <ol className="space-y-0">
      {steps.map((s, i) => (
        <li
          key={s}
          className="relative flex gap-3 pb-4 text-sm before:absolute before:left-[7px] before:top-4 before:h-full before:w-px before:bg-border last:before:hidden"
        >
          <CheckCircle2 className="relative z-10 mt-0.5 size-4 shrink-0 bg-background text-success" />
          <span className="font-mono text-xs">{s}</span>
        </li>
      ))}
    </ol>
  );
}

export function CommandSearch({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
}) {
  const navigate = useNavigate();
  const { t } = usePreferences();
  const { query: channelsQuery } = useChannelsData();
  const { query: recordingsQuery } = useRecordingsData();
  const channelItems = channelsQuery.data ?? [];
  const recordingItems = recordingsQuery.data ?? [];
  const go = (fn: () => void) => {
    onOpenChange(false);
    fn();
  };
  return (
    <CommandDialog open={open} onOpenChange={onOpenChange}>
      <CommandInput placeholder={t("Search channels or recordings…")} />
      <CommandList>
        <CommandEmpty>
          <div className="py-4">
            <p className="text-sm font-medium">{t("No results found")}</p>
            <p className="mt-1 text-xs text-muted-foreground">
              Try a creator name, @handle, or recording date.
            </p>
          </div>
        </CommandEmpty>
        <CommandGroup heading={t("Channels")}>
          {channelItems.map((c) => (
            <CommandItem
              key={c.id}
              value={`${c.name} ${c.handle}`}
              onSelect={() => go(() => navigate({ to: "/channels/$id", params: { id: c.id } }))}
            >
              <CreatorAvatar channel={c} size="sm" />
              <span className="flex-1">
                {c.name} <span className="text-muted-foreground">{c.handle}</span>
              </span>
              <StatusBadge status={c.status} />
            </CommandItem>
          ))}
        </CommandGroup>
        <CommandGroup heading={t("Recordings")}>
          {recordingItems.map((r) => (
            <CommandItem
              key={r.id}
              value={`${r.handle} ${r.title} ${r.date}`}
              onSelect={() => go(() => navigate({ to: "/recordings/$id", params: { id: r.id } }))}
            >
              <FileVideo className="text-muted-foreground" />
              <span className="flex-1 truncate">
                {r.handle} — {r.title}
              </span>
              <span className="font-mono text-xs text-muted-foreground">{r.duration}</span>
            </CommandItem>
          ))}
        </CommandGroup>
      </CommandList>
    </CommandDialog>
  );
}
export function useChannelControls(channel: ChannelModel) {
  const pauseChannel = usePauseChannelMutation();
  const resumeChannel = useResumeChannelMutation();
  const deleteChannel = useDeleteChannelMutation();
  const [dialog, setDialog] = useState<null | "pause" | "remove">(null);
  const [demoOn, setDemoOn] = useState(channel.monitoring && channel.status !== "Paused");
  const [demoRemoved, setDemoRemoved] = useState(false);
  const on = isDemoMode ? demoOn : channel.backendStatus === "active";
  const pending =
    pauseChannel.isPending || resumeChannel.isPending || deleteChannel.isPending;

  const resume = async () => {
    try {
      await resumeChannel.mutateAsync(channel.id);
      if (isDemoMode) setDemoOn(true);
      toast.success(`Monitoring resumed for ${channel.handle}`, {
        description: "We’ll record the next livestream automatically.",
      });
    } catch (error) {
      toast.error("Could not resume monitoring", {
        description: channelActionErrorMessage(error),
      });
    }
  };

  const toggle = (next: boolean) => {
    if (pending) return;
    if (next) {
      void resume();
    } else {
      setDialog("pause");
    }
  };

  const dialogs = (
    <>
      <ConfirmDialog
        open={dialog === "pause"}
        onOpenChange={(open) => !open && setDialog(null)}
        title="Pause monitoring?"
        body={`Future livestreams from ${channel.handle} won’t be recorded until you resume monitoring. Existing recordings aren’t affected.`}
        confirmLabel="Pause monitoring"
        confirmDisabled={pending}
        onConfirm={() => {
          void pauseChannel
            .mutateAsync(channel.id)
            .then(() => {
              if (isDemoMode) setDemoOn(false);
              setDialog(null);
              toast(`Monitoring paused for ${channel.handle}`, {
                description: "Future livestreams will not be recorded.",
              });
            })
            .catch((error) => {
              toast.error("Could not pause monitoring", {
                description: channelActionErrorMessage(error),
              });
            });
        }}
      />
      <ConfirmDialog
        destructive
        open={dialog === "remove"}
        onOpenChange={(open) => !open && setDialog(null)}
        title="Remove channel?"
        body={`We’ll stop monitoring ${channel.handle}. Existing recordings stay in your library until you delete them or they expire.`}
        confirmLabel="Remove channel"
        confirmDisabled={pending}
        onConfirm={() => {
          void deleteChannel
            .mutateAsync(channel.id)
            .then(() => {
              if (isDemoMode) setDemoRemoved(true);
              setDialog(null);
              toast.success(`${channel.handle} removed`, {
                description: "Existing recordings are still in your library.",
              });
            })
            .catch((error) => {
              toast.error("Could not remove channel", {
                description: channelActionErrorMessage(error),
              });
            });
        }}
      />
    </>
  );

  return {
    on,
    toggle,
    removed: isDemoMode ? demoRemoved : deleteChannel.isSuccess,
    pending,
    openPause: () => setDialog("pause"),
    openRemove: () => setDialog("remove"),
    dialogs,
  };
}
export function ExpiryText({
  recording,
  prefix = false,
}: {
  recording: RecordingModel;
  prefix?: boolean;
}) {
  if (recording.expiresDays === null) return <span className="text-muted-foreground">—</span>;
  const critical = recording.expireTone === "critical";
  const warn = recording.expireTone === "warning";
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1",
        critical
          ? "font-medium text-destructive"
          : warn
            ? "text-warning-foreground"
            : "text-muted-foreground",
      )}
    >
      {(critical || warn) && <Clock3 className="size-3" />}
      {critical
        ? "Expires tomorrow"
        : prefix
          ? `Expires in ${recording.expires}`
          : recording.expires}
    </span>
  );
}
type LookupState =
  "idle" | "resolving" | "found" | "invalid" | "notfound" | "exists" | "unavailable" | "limit";
export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  body,
  confirmLabel,
  onConfirm,
  destructive = false,
  children,
  confirmDisabled = false,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  title: string;
  body: string;
  confirmLabel: string;
  onConfirm: () => void;
  destructive?: boolean;
  children?: ReactNode;
  confirmDisabled?: boolean;
}) {
  const { t } = usePreferences();
  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent className="w-[calc(100vw-2rem)] rounded-lg">
        <AlertDialogHeader>
          <AlertDialogTitle>{t(title)}</AlertDialogTitle>
          <AlertDialogDescription>{t(body)}</AlertDialogDescription>
        </AlertDialogHeader>
        {children}
        <AlertDialogFooter className="gap-2">
          <AlertDialogCancel>{t("Cancel")}</AlertDialogCancel>
          <AlertDialogAction
            disabled={confirmDisabled}
            onClick={(e) => {
              e.preventDefault();
              onConfirm();
            }}
            className={cn(destructive && buttonVariants({ variant: "destructive" }))}
          >
            {t(confirmLabel)}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
export function StateBanner({
  tone = "info",
  title,
  body,
  action,
  icon,
}: {
  tone?: "info" | "warning" | "error" | "success";
  title: string;
  body?: ReactNode;
  action?: ReactNode;
  icon?: ElementType;
}) {
  const { t } = usePreferences();
  const I = icon ?? (tone === "success" ? CheckCircle2 : tone === "info" ? Info : AlertTriangle);
  const styles = {
    info: "border-info/25 bg-info-subtle [&>svg]:text-info",
    warning: "border-warning/30 bg-warning-subtle [&>svg]:text-warning-foreground",
    error: "border-destructive/25 bg-recording-subtle [&>svg]:text-destructive",
    success: "border-success/25 bg-success-subtle [&>svg]:text-success",
  }[tone];
  return (
    <div
      role={tone === "error" || tone === "warning" ? "alert" : "status"}
      className={cn("flex flex-col gap-3 rounded-lg border p-4 sm:flex-row sm:items-start", styles)}
    >
      <I className="size-4 shrink-0 sm:mt-0.5" />
      <div className="flex-1">
        <p className="text-sm font-medium">{t(title)}</p>
        {body && (
          <div className="mt-1 text-xs leading-5 text-muted-foreground">
            {typeof body === "string" ? t(body) : body}
          </div>
        )}
      </div>
      {action && <div className="shrink-0">{action}</div>}
    </div>
  );
}
export function PrototypeStateBar<T extends string>({
  label = "Demo controls",
  value,
  options,
  onChange,
}: {
  label?: string;
  value: T;
  options: readonly { value: T; label: string }[];
  onChange: (v: T) => void;
}) {
  const { t } = usePreferences();
  if (!isDemoMode) return null;
  return (
    <div className="mb-5 flex flex-col gap-2 rounded-lg border border-dashed border-warning/40 bg-warning-subtle/40 p-2 sm:flex-row sm:items-center">
      <span className="px-2 text-[10px] font-semibold uppercase text-muted-foreground">
        {t(label)}
      </span>
      <div role="radiogroup" aria-label={t(label)} className="flex gap-1 overflow-x-auto">
        {options.map((o) => (
          <button
            type="button"
            role="radio"
            aria-checked={value === o.value}
            key={o.value}
            onClick={() => onChange(o.value)}
            className={cn(
              "h-7 shrink-0 rounded-md px-2.5 text-xs font-medium text-muted-foreground transition-colors hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
              value === o.value && "bg-background text-foreground shadow-sm ring-1 ring-border",
            )}
          >
            {t(o.label)}
          </button>
        ))}
      </div>
    </div>
  );
}
export function SuccessState({
  title,
  body,
  action,
}: {
  title: string;
  body: string;
  action?: ReactNode;
}) {
  const { t } = usePreferences();
  return (
    <div className="text-center">
      <span className="mx-auto grid size-12 place-items-center rounded-full bg-success-subtle text-success">
        <CheckCircle2 className="size-6" />
      </span>
      <h1 className="mt-5 text-2xl font-semibold">{t(title)}</h1>
      <p className="mx-auto mt-2 max-w-sm text-sm text-muted-foreground">{t(body)}</p>
      {action && (
        <div className="mt-7 flex flex-col justify-center gap-2 sm:flex-row">{action}</div>
      )}
    </div>
  );
}
export function PasswordField({
  label = "Password",
  id,
  value,
  onChange,
  showStrength = false,
}: {
  label?: string;
  id: string;
  value: string;
  onChange: (v: string) => void;
  showStrength?: boolean;
}) {
  const { t } = usePreferences();
  const score = [
    value.length >= 8,
    /[A-Z]/.test(value) && /[a-z]/.test(value),
    /\d/.test(value),
    /[^A-Za-z0-9]/.test(value),
  ].filter(Boolean).length;
  const text = ["Too short", "Weak", "Fair", "Good", "Strong"][value.length < 8 ? 0 : score]!;
  return (
    <div>
      <label htmlFor={id} className="block text-sm font-medium">
        {t(label)}
      </label>
      <Input
        id={id}
        type="password"
        className="mt-2"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder="••••••••"
        autoComplete="new-password"
      />
      {showStrength &&
        (value ? (
          <div className="mt-2">
            <div className="flex gap-1">
              {[0, 1, 2, 3].map((i) => (
                <span
                  key={i}
                  className={cn(
                    "h-1 flex-1 rounded-full bg-muted",
                    value.length >= 8 &&
                      i < score &&
                      (score <= 1 ? "bg-destructive" : score === 2 ? "bg-warning" : "bg-success"),
                  )}
                />
              ))}
            </div>
            <p className="mt-1 text-xs text-muted-foreground">
              {text} · Use 8+ characters with a mix of letters, numbers, and symbols.
            </p>
          </div>
        ) : (
          <p className="mt-2 text-xs text-muted-foreground">At least 8 characters.</p>
        ))}
    </div>
  );
}