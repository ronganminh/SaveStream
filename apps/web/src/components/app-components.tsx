import { Link, useNavigate, useRouterState } from "@tanstack/react-router";
import {
  useEffect,
  useMemo,
  useState,
  type ComponentProps,
  type ElementType,
  type ReactNode,
} from "react";
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
  HardDrive,
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
  ShieldAlert,
  ShieldCheck,
  Sparkles,
  Sun,
  Trash2,
  UserRound,
  Users,
  Video,
  X,
  Eye,
  EyeOff,
  LogOut,
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
  isAdminRole,
  isDemoMode,
  isProductionMode,
  productionBackendConnected,
} from "@/lib/app-config";
import { useAuth } from "@/auth/auth-context";
import { meta, publicMeta } from "@/lib/route-metadata";
import { planCatalog } from "@/mocks/demo-plan-catalog";
import { formatDate, pluralize } from "@/lib/formatters";
import type { ChannelModel, ChannelStatus, RecordingModel } from "@/repositories";
import {
  useActiveRecordingData,
  useChannelsData,
  useCreatorPreview,
  useEntitlementData,
  usePublicPricingData,
  useRecordingsData,
} from "@/hooks/use-domain-data";
import { freeWebSentence } from "@/lib/plan-facts";
import {
  channelActionErrorMessage,
  existingWatchId,
  useCreateChannelMutation,
  useDeleteChannelMutation,
  usePauseChannelMutation,
  useResumeChannelMutation,
  watchQuotaLimit,
} from "@/hooks/use-channel-mutations";
import { displayNameFromTikTokUsername, parseTikTokSource } from "@/lib/tiktok-source";
import {
  recordingActionErrorMessage,
  useDeleteRecordingMutation,
} from "@/hooks/use-recording-mutations";
import { useRecordingDownload } from "@/hooks/use-recording-download";
import {
  GlobalBanners,
  GlobalSearch,
  HelpMenu,
  useCreditSummary,
} from "@/components/app/shell-extras";

export { meta, publicMeta };
const mainNav = [
  { to: "/overview", label: "Overview", icon: LayoutDashboard },
  { to: "/channels", label: "Channels", icon: Radio },
  { to: "/recordings", label: "Recordings", icon: FileVideo },
  { to: "/usage", label: "Usage", icon: Gauge },
  { to: "/billing", label: "Billing", icon: CreditCard },
  { to: "/notifications", label: "Notifications", icon: Bell },
  { to: "/settings", label: "Settings", icon: Settings },
  { to: "/help", label: "Help", icon: CircleHelp },
] as const;
const mobileNav = mainNav.slice(0, 3);
const adminNav = [
  { to: "/admin/overview", label: "Admin overview", icon: LayoutDashboard },
  { to: "/admin/users", label: "Users", icon: Users },
  { to: "/admin/payments", label: "Payments", icon: CreditCard },
  { to: "/admin/catalog", label: "Catalog", icon: Sparkles },
  { to: "/admin/jobs", label: "Jobs & LIVE", icon: FileVideo },
  { to: "/admin/safety", label: "Safety", icon: ShieldAlert },
  { to: "/admin/reports", label: "Problem reports", icon: AlertTriangle },
  { to: "/admin/operations", label: "Operations", icon: HardDrive },
  { to: "/admin/system", label: "System", icon: Activity },
  { to: "/admin/workers", label: "Workers & queues", icon: MonitorCog },
  { to: "/admin/errors", label: isDemoMode ? "Errors" : "Audit & error log", icon: AlertTriangle },
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
  const initials =
    name
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase() ?? "")
      .join("") ||
    authUser.email[0]?.toUpperCase() ||
    "U";

  return {
    name,
    email: authUser.email,
    initials,
    subLabel: isAdminRole(authUser.role)
      ? `${authUser.role === "admin" ? "Owner" : authUser.role[0]!.toUpperCase() + authUser.role.slice(1)} admin`
      : "Account",
  };
}
export function Logo({
  compact = false,
  homeTo = "/",
}: {
  compact?: boolean;
  homeTo?: "/" | "/overview";
}) {
  const { t } = usePreferences();
  return (
    <Link
      to={homeTo}
      aria-label={`SaveStream · ${homeTo === "/" ? t("Go home") : t("Overview")}`}
      className="flex min-w-0 items-center gap-2.5 font-semibold"
    >
      <img src="/savestream-mark.svg" alt="" className="size-8 shrink-0" width="32" height="32" />
      {!compact && <span className="truncate">SaveStream</span>}
    </Link>
  );
}
/**
 * Creator avatar: the channel's TikTok picture (served by the API from a
 * cached copy, the same `creator.avatar_url` the mobile app shows), falling
 * back to initials when there is none or the image fails to load.
 */
export function AvatarCircle({
  src,
  initials,
  tone,
  size = "md",
}: {
  src?: string | null | undefined;
  initials: string;
  tone?: string | undefined;
  size?: "xs" | "sm" | "md" | "lg" | "xl";
}) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [src]);
  const image = src && /^https?:\/\//.test(src) && !failed ? src : null;
  return (
    <div
      className={cn(
        "grid shrink-0 place-items-center overflow-hidden rounded-full bg-gradient-to-br font-semibold text-avatar-foreground",
        tone ?? "from-avatar-one to-avatar-one-end",
        size === "xs"
          ? "size-6 text-[9px]"
          : size === "sm"
            ? "size-8 text-[10px]"
            : size === "lg"
              ? "size-14 text-sm"
              : size === "xl"
                ? "size-[72px] text-xl"
                : "size-10 text-xs",
      )}
    >
      {image ? (
        <img
          src={image}
          alt=""
          // Small and above the fold in lists; lazy loading only left them
          // blank (naturalWidth 0) until scrolled into view.
          decoding="async"
          referrerPolicy="no-referrer"
          className="size-full object-cover"
          onError={() => setFailed(true)}
        />
      ) : (
        initials
      )}
    </div>
  );
}
export function CreatorAvatar({
  channel,
  size = "md",
}: {
  channel: Pick<ChannelModel, "initials" | "tone" | "avatarUrl">;
  size?: "xs" | "sm" | "md" | "lg" | "xl";
}) {
  return (
    <AvatarCircle
      src={channel.avatarUrl}
      initials={channel.initials}
      tone={channel.tone}
      size={size}
    />
  );
}
export function RecordingCreatorAvatar({
  recording,
  size = "xs",
}: {
  recording: RecordingModel;
  size?: "xs" | "sm" | "md" | "lg";
}) {
  return (
    <AvatarCircle
      src={recording.avatarUrl}
      initials={recording.initials ?? recording.handle.replace(/^@/, "").slice(0, 2).toUpperCase()}
      tone={recording.tone}
      size={size}
    />
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
// Badge palette from the redesign handoff (.b-* classes).
const statusStyles: Record<Status, string> = {
  Recording: "bg-recording-subtle text-live-ink",
  Live: "bg-surface text-live-ink shadow-[inset_0_0_0_1.5px_var(--recording)]",
  Processing: "bg-primary-subtle text-accent-ink",
  Ready: "bg-success-subtle text-success",
  Waiting: "bg-info-subtle text-info",
  Missed: "bg-neutral-soft text-muted-foreground",
  Offline: "bg-neutral-soft text-muted-foreground",
  Paused: "bg-warning-subtle text-warning-foreground",
  Error: "bg-recording-subtle text-destructive",
};
const pillTones = {
  neutral: "bg-surface-2 text-muted-foreground",
  success: "bg-success-subtle text-success",
  info: "bg-info-subtle text-info",
  accent: "bg-primary-subtle text-accent-ink",
} as const;
/** Rounded label for public pages (design `.badge`), not tied to a status. */
export function Pill({
  tone = "neutral",
  children,
}: {
  tone?: keyof typeof pillTones;
  children: ReactNode;
}) {
  return (
    <span
      className={cn(
        "inline-flex h-[30px] items-center gap-1.5 whitespace-nowrap rounded-full px-3 text-[13px] font-bold",
        pillTones[tone],
      )}
    >
      {children}
    </span>
  );
}
export function StatusBadge({ status, pulse = false }: { status: Status; pulse?: boolean }) {
  const { t } = usePreferences();
  const icon =
    status === "Ready" ? (
      <Check className="size-3" />
    ) : status === "Processing" ? (
      <span className="size-3 animate-spin rounded-full border border-current border-t-transparent" />
    ) : status === "Paused" ? (
      <Pause className="size-3" />
    ) : status === "Error" || status === "Missed" ? (
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
        "inline-flex h-6 items-center gap-1.5 whitespace-nowrap rounded-full px-[9px] text-xs font-bold leading-none",
        statusStyles[status],
      )}
    >
      {icon}
      {t(status === "Live" ? "LIVE · not recording" : status)}
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
      <div className="mt-3 font-mono text-[28px] font-semibold tracking-[-.02em] text-foreground">
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
  leading,
}: {
  title: string;
  subtitle?: string;
  action?: ReactNode;
  /** Shown before the title, e.g. a creator avatar. */
  leading?: ReactNode;
}) {
  const { t } = usePreferences();
  return (
    <header className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
      <div className="flex items-start gap-3">
        {leading}
        <div>
          <h1 className="text-[28px] font-extrabold leading-[1.15] tracking-[-.025em]">
            {t(title)}
          </h1>
          {subtitle && (
            <p className="mt-1 max-w-2xl text-[15px] text-muted-foreground">{t(subtitle)}</p>
          )}
        </div>
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
function isNavActive(path: string, to: string) {
  return path === to || path.startsWith(to + "/");
}

function SidebarCredits({ onNavigate }: { onNavigate: () => void }) {
  const credits = useCreditSummary();
  if (!credits.loaded) return null;
  return (
    <div className="flex flex-col gap-2.5 rounded-[14px] border bg-surface-2 p-4">
      <div className="flex items-center justify-between">
        <span className="text-sm font-semibold text-muted-foreground">Credits</span>
        <span className="font-mono text-sm font-semibold">{credits.label}</span>
      </div>
      <div
        className="h-2 overflow-hidden rounded-full bg-surface-3"
        role="meter"
        aria-label="Credits left"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={credits.percent}
      >
        <span
          className={cn(
            "block h-full rounded-full",
            credits.state === "out"
              ? "bg-destructive"
              : credits.state === "low"
                ? "bg-warning"
                : "bg-gradient-to-r from-primary to-accent",
          )}
          style={{ width: `${Math.max(credits.percent, credits.minutes > 0 ? 4 : 0)}%` }}
        />
      </div>
      <Button asChild variant="outline" size="sm" className="w-full">
        <Link to="/billing" onClick={onNavigate}>
          Buy credits
        </Link>
      </Button>
    </div>
  );
}

export function AppSidebar({ open, onClose }: { open: boolean; onClose: () => void }) {
  const path = useRouterState({ select: (s) => s.location.pathname });
  const { t } = usePreferences();
  const { identity } = useAuth();
  const unread = useNotifications().filter((n) => !n.read).length;
  const canSeeAdmin = isAdminRole(identity.role);
  const visibleAdminNav = adminNav.filter((entry) => {
    if (entry.to === "/admin/overview") {
      return ["owner", "admin", "finance"].includes(identity.role);
    }
    if (entry.to === "/admin/reports") {
      return ["owner", "admin", "support"].includes(identity.role);
    }
    return true;
  });
  const item = (it: (typeof mainNav)[number] | (typeof adminNav)[number]) => {
    const active = isNavActive(path, it.to);
    const badge = it.to === "/notifications" && unread > 0 ? unread : null;
    return (
      <Link
        key={it.to}
        to={it.to}
        onClick={onClose}
        aria-current={active ? "page" : undefined}
        className={cn(
          "flex min-h-10 items-center gap-3 rounded-[10px] px-3 text-sm font-semibold text-muted-foreground transition-colors hover:bg-surface-2 hover:text-foreground focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-ring/25",
          active &&
            "bg-primary-subtle text-accent-ink hover:bg-primary-subtle hover:text-accent-ink",
        )}
      >
        <it.icon className="size-5" />
        <span className="flex-1">{it.to.startsWith("/admin/") ? it.label : t(it.label)}</span>
        {badge !== null && (
          <span className="grid h-5 min-w-5 place-items-center rounded-full bg-primary px-1.5 font-mono text-[11px] font-semibold text-primary-foreground">
            {badge > 99 ? "99+" : badge}
          </span>
        )}
      </Link>
    );
  };
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
        aria-label={t("App navigation")}
        className={cn(
          "fixed inset-y-0 left-0 z-[var(--z-drawer)] flex w-[252px] flex-col border-r bg-surface transition-transform lg:translate-x-0",
          open ? "translate-x-0" : "-translate-x-full",
        )}
      >
        <div className="flex h-[68px] items-center justify-between px-5">
          <Logo homeTo="/overview" />
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
        <nav aria-label={t("Workspace")} className="flex-1 overflow-y-auto px-3.5 py-2">
          <div className="space-y-0.5">{mainNav.map(item)}</div>
          {canSeeAdmin && (
            <div className="mt-5 space-y-0.5 border-t pt-4">
              <p className="mb-1.5 flex items-center gap-2 px-3 text-[11px] font-bold uppercase tracking-[.08em] text-muted-foreground">
                <ShieldCheck className="size-3.5" />
                Admin
              </p>
              {visibleAdminNav.map(item)}
            </div>
          )}
        </nav>
        <div className="space-y-2 p-3.5 pt-4">
          <div className="grid grid-cols-2 gap-1 lg:hidden">
            <ThemeMenu full />
          </div>
          <SidebarCredits onNavigate={onClose} />
        </div>
      </aside>
    </>
  );
}

export function AppTopbar({ onMenu }: { onMenu: () => void }) {
  const [cmd, setCmd] = useState(false);
  const navigate = useNavigate();
  const path = useRouterState({ select: (s) => s.location.pathname });
  const { t } = usePreferences();
  const { signOut } = useAuth();
  const account = useShellAccount();
  const credits = useCreditSummary();
  const list = useNotifications();
  const unread = list.filter((n) => !n.read).length;
  return (
    <div className="sticky top-0 z-[var(--z-sticky)] flex h-[68px] items-center gap-2 border-b bg-surface/90 px-3 backdrop-blur-md sm:gap-3 sm:px-4 lg:px-8">
      <Button
        variant="ghost"
        size="icon"
        onClick={onMenu}
        className="lg:hidden"
        aria-label={t("Open menu")}
      >
        <Menu />
      </Button>
      <GlobalSearch />
      {path.startsWith("/admin") && (
        <span
          className="hidden h-[26px] shrink-0 items-center gap-1.5 whitespace-nowrap rounded-full bg-primary-subtle px-2 text-xs font-bold text-accent-ink sm:inline-flex xl:px-2.5"
          title="Admin mode"
        >
          <ShieldCheck className="size-3" aria-hidden="true" />
          {/* Icon only until there is room, so the search placeholder isn't cut. */}
          <span className="sr-only xl:not-sr-only">Admin mode</span>
        </span>
      )}
      <div className="ml-auto flex min-w-0 items-center gap-1 sm:gap-2">
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
        {credits.loaded && (
          <Link
            to="/billing"
            aria-label={`${credits.label} of credits left`}
            className="hidden h-10 items-center gap-2 rounded-[10px] border px-3 text-sm font-semibold hover:bg-surface-2 xl:inline-flex"
          >
            <span
              aria-hidden="true"
              className={cn(
                "size-2 rounded-full",
                credits.state === "out"
                  ? "bg-destructive"
                  : credits.state === "low"
                    ? "bg-warning"
                    : "bg-success",
              )}
            />
            <span className="font-mono">{credits.label}</span>
            <span className="font-medium text-muted-foreground">left</span>
          </Link>
        )}
        <Button asChild size="sm" className="h-9 shrink-0 px-2 sm:px-3">
          <Link to="/billing" aria-label={t("Buy credits")}>
            <Plus />
            <span className="hidden sm:inline">{t("Buy credits")}</span>
          </Link>
        </Button>
        <HelpMenu />
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
                <span className="absolute right-2 top-2 size-2 rounded-full bg-destructive ring-2 ring-surface" />
              )}
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-[min(360px,calc(100vw-2rem))] p-0">
            <div className="flex items-center justify-between gap-3 border-b px-4 py-3">
              <p className="font-semibold">{t("Notifications")}</p>
              <button
                type="button"
                disabled={!unread}
                onClick={() => void notificationStore.markAllRead()}
                className="text-xs font-semibold text-accent-ink disabled:text-muted-foreground"
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
              className="block border-t p-3 text-center text-xs font-semibold text-accent-ink"
            >
              {t("View all notifications")}
            </Link>
          </DropdownMenuContent>
        </DropdownMenu>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button
              type="button"
              className="flex items-center gap-2.5 rounded-[12px] p-1 text-left hover:bg-surface-2 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-ring/25"
              aria-label={`${t("Account menu")}: ${account.name}`}
            >
              <span className="grid size-9 place-items-center rounded-full bg-gradient-to-br from-avatar-one to-avatar-one-end text-[13px] font-extrabold text-avatar-foreground">
                {account.initials}
              </span>
              <span className="hidden flex-col leading-tight lg:flex">
                <b className="max-w-[140px] truncate text-sm">{account.name}</b>
                <span className="whitespace-nowrap text-xs text-muted-foreground">
                  {account.subLabel}
                </span>
              </span>
              <ChevronDown className="hidden size-4 text-muted-foreground lg:block" />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuLabel className="font-normal">
              <p className="text-sm font-medium">{account.name}</p>
              <p className="text-xs text-muted-foreground">{account.email}</p>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={() => navigate({ to: "/settings/account" })}>
              <UserRound />
              {t("Account settings")}
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => navigate({ to: "/billing" })}>
              <CreditCard />
              {t("Billing")}
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => navigate({ to: "/usage" })}>
              <Gauge />
              {t("Usage")}
            </DropdownMenuItem>
            <div className="hidden px-1 py-1 lg:block">
              <ThemeMenu full />
            </div>
            <DropdownMenuSeparator />
            <DropdownMenuItem
              onSelect={(event) => {
                event.preventDefault();
                void signOut().finally(() => navigate({ to: "/sign-in" }));
              }}
            >
              <LogOut />
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
          <div className="mx-auto w-fit">
            <Logo />
          </div>
          <h1 className="mt-6 text-2xl font-semibold">{t("Backend not connected")}</h1>
          <p className="mt-3 text-sm leading-6 text-muted-foreground">
            {t(
              "This screen is unavailable in production until authentication and API services are connected.",
            )}
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
        <div className="lg:pl-[252px]">
          <AppTopbar onMenu={() => setOpen(true)} />
          <GlobalBanners />
          <main className="mx-auto min-w-0 max-w-[1440px] overflow-x-clip p-4 pb-24 sm:p-6 lg:p-8">
            {children}
          </main>
          <nav
            aria-label={t("Primary")}
            className="fixed inset-x-0 bottom-0 z-[var(--z-sticky)] grid grid-cols-3 border-t bg-background px-1 pt-1 pb-[max(.25rem,env(safe-area-inset-bottom))] lg:hidden"
          >
            {mobileNav.map((i) => (
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
export function ActiveRecordingCard() {
  const { t } = usePreferences();
  const { query: channelsQuery } = useChannelsData();
  const { query: activeQuery, state: activeState } = useActiveRecordingData();
  const recording = activeQuery.data;

  if (activeState.kind === "empty") {
    // Describe what is really happening instead of always promising that
    // recording "will start automatically".
    const channels = channelsQuery.data ?? [];
    const monitored = channels.filter((item) => item.monitoring);
    const liveNotRecording = channels.filter((item) => item.status === "Live");
    const autoRecording = monitored.filter((item) => item.autoRecord);
    let body: string;
    let action: ReactNode = null;
    if (channels.length === 0) {
      body = t("You have no channels yet. Add a TikTok channel to start monitoring.");
      action = (
        <Button size="sm" variant="outline" asChild>
          <Link to="/channels">{t("Add channel")}</Link>
        </Button>
      );
    } else if (liveNotRecording.length > 0) {
      const first = liveNotRecording[0]!;
      body =
        liveNotRecording.length === 1
          ? `${first.handle} is LIVE but not being recorded. ${first.liveReason ?? ""}`.trim()
          : `${liveNotRecording.length} channels are LIVE but not being recorded.`;
      action = (
        <Button size="sm" variant="outline" asChild>
          <Link to="/channels/$id" params={{ id: first.id }}>
            {t("View channel")}
          </Link>
        </Button>
      );
    } else if (monitored.length === 0) {
      body = t("Monitoring is paused for all your channels. Resume a channel to get LIVE alerts.");
    } else if (autoRecording.length === 0) {
      body = t(
        "We’re monitoring your channels and will notify you when one goes live. Automatic recording is off.",
      );
    } else {
      body = t(
        "We’re monitoring your enabled channels. Recording will start automatically when one goes live.",
      );
    }
    return (
      <section className="border-y bg-surface px-5 py-8">
        <div className="flex items-start gap-4">
          <span className="grid size-10 place-items-center rounded-full bg-muted">
            <Radio className="size-4 text-muted-foreground" />
          </span>
          <div>
            <h2 className="font-semibold">{t("No active recordings")}</h2>
            <p className="mt-1 text-sm text-muted-foreground">{body}</p>
            {action && <div className="mt-3">{action}</div>}
          </div>
        </div>
      </section>
    );
  }

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
          {channel.live} · {pluralize(channel.recordings, "recording")}
        </span>
        <Link to="/channels/$id" params={{ id: channel.id }} className="font-medium text-primary">
          {t("View")}
        </Link>
      </div>
      {c.dialogs}
    </div>
  );
}
const channelLineDot: Record<ChannelStatus, string> = {
  Recording: "bg-recording animate-pulse",
  Live: "bg-recording",
  Waiting: "bg-info",
  Offline: "bg-muted-foreground/50",
  Paused: "bg-warning",
  Error: "bg-destructive",
};

function channelStatusLine(channel: ChannelModel, on: boolean): string {
  if (!on || channel.status === "Paused")
    return "Paused · not being checked, new LIVEs won’t be recorded";
  switch (channel.status) {
    case "Recording":
      return "LIVE · recording on our servers";
    case "Live":
      return channel.liveReason ?? "LIVE · not recording";
    case "Error":
      return "Checks are failing — open the channel to fix it";
    case "Offline":
      return `Offline · watching for the next LIVE · checked ${channel.checked}`;
    default:
      return `Waiting for the next LIVE · checked ${channel.checked}`;
  }
}

export function ChannelGridCard({ channel }: { channel: ChannelModel }) {
  const c = useChannelControls(channel);
  if (c.removed) return null;
  const status: ChannelStatus = c.on ? channel.status : "Paused";
  const fix =
    status === "Recording" && channel.activeRecordingId ? (
      <Button asChild size="sm">
        <Link to="/recordings/$id" params={{ id: channel.activeRecordingId }}>
          Watch
        </Link>
      </Button>
    ) : status === "Live" || status === "Error" ? (
      <Button asChild size="sm">
        <Link to="/channels/$id" params={{ id: channel.id }}>
          {status === "Error" ? "Fix" : "Details"}
        </Link>
      </Button>
    ) : null;
  return (
    <article className="flex flex-col gap-4 rounded-[18px] border bg-surface p-5 shadow-sm transition-shadow hover:shadow-md">
      <div className="flex items-center gap-3">
        <CreatorAvatar channel={channel} />
        <Link
          to="/channels/$id"
          params={{ id: channel.id }}
          className="min-w-0 flex-1 rounded-sm focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-ring/25"
        >
          <b className="block truncate">{channel.handle}</b>
          <span className="block truncate text-xs text-muted-foreground">{channel.name}</span>
        </Link>
        <StatusBadge status={status} pulse={status === "Recording"} />
      </div>
      <div className="flex min-h-12 items-center gap-2.5 rounded-[12px] bg-surface-2 px-3.5 py-2.5 text-sm">
        <span
          aria-hidden="true"
          className={cn("size-2 shrink-0 rounded-full", channelLineDot[status])}
        />
        <span className="min-w-0 flex-1">{channelStatusLine(channel, c.on)}</span>
        {fix}
      </div>
      <dl className="grid grid-cols-3 gap-x-3 gap-y-1 text-[13px]">
        <dt className="text-xs text-muted-foreground">Recordings</dt>
        <dt className="text-xs text-muted-foreground">Last LIVE</dt>
        <dt className="text-xs text-muted-foreground">Hours recorded</dt>
        <dd className="font-mono font-semibold">{channel.recordings}</dd>
        <dd className="font-semibold">{channel.live}</dd>
        <dd className="font-mono font-semibold">{channel.recordedHours}</dd>
      </dl>
      <div className="flex items-center gap-2.5 border-t pt-3">
        <Switch
          checked={c.on}
          onCheckedChange={c.toggle}
          disabled={c.pending}
          aria-label={`Monitoring for ${channel.handle}`}
        />
        <span className="text-sm font-bold">Monitoring {c.on ? "on" : "off"}</span>
        <div className="ml-auto flex items-center gap-1">
          <Button asChild variant="outline" size="sm">
            <Link to="/channels/$id" params={{ id: channel.id }}>
              Open
            </Link>
          </Button>
          <MoreMenu channel={channel} controls={c} />
        </div>
      </div>
      {c.dialogs}
    </article>
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
      <Link
        to="/channels/$id"
        params={{ id: recording.channelId }}
        className="flex min-w-0 items-center gap-2 hover:underline"
      >
        <RecordingCreatorAvatar recording={recording} />
        <span className="truncate">{recording.handle}</span>
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
        <div className="flex items-start gap-2">
          <RecordingCreatorAvatar recording={recording} size="sm" />
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
  const downloadRecording = useRecordingDownload();
  const deleteRecording = useDeleteRecordingMutation();

  const download = () => {
    if (isDemoMode) {
      toast.success("Download started", {
        description: `${recording.size} · ${recording.handle} — ${recording.title}`,
      });
      return;
    }

    void downloadRecording.start(recording);
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
            disabled={recording.status !== "Ready" || downloadRecording.isPreparing}
            onSelect={download}
          >
            <Download />
            {downloadRecording.isPreparing ? t("Preparing…") : t("Download")}
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
  loadSource,
  elapsed,
  failedDetail,
  portrait = false,
}: {
  state?: "ready" | "active" | "processing" | "failed";
  /** TikTok LIVEs are vertical: a 9:16 frame instead of 16:9. */
  portrait?: boolean;
  /** Resolves a playable URL; errors should carry a user-facing message. */
  loadSource?: () => Promise<string>;
  elapsed?: string;
  failedDetail?: string;
}) {
  const { t } = usePreferences();
  const [src, setSrc] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const play = async () => {
    if (!loadSource || loading) return;
    setLoading(true);
    setError(null);
    try {
      setSrc(await loadSource());
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : t("Playback is unavailable right now."));
    } finally {
      setLoading(false);
    }
  };

  if (src) {
    return (
      <div
        className={cn(
          "w-full overflow-hidden bg-black",
          portrait ? "aspect-[9/16] rounded-[20px]" : "rounded-lg",
        )}
      >
        <video
          className={cn("mx-auto w-full object-contain", portrait ? "h-full" : "max-h-[620px]")}
          src={src}
          controls
          autoPlay
          playsInline
          preload="metadata"
          onError={() => {
            setSrc(null);
            setError(t("Playback is unavailable right now."));
          }}
        />
      </div>
    );
  }

  return (
    <div
      className={cn(
        "relative grid w-full place-items-center overflow-hidden bg-player text-player-foreground",
        portrait ? "aspect-[9/16] rounded-[20px]" : "aspect-video max-h-[620px] rounded-lg",
      )}
    >
      <div className="absolute inset-0 bg-player-grid" />
      {state === "ready" && (
        <div className="relative text-center">
          <button
            type="button"
            onClick={() => void play()}
            disabled={loading || (!loadSource && !isDemoMode)}
            aria-label={t("Play video")}
            className="mx-auto grid size-16 place-items-center rounded-full bg-player-foreground text-player transition hover:scale-105 disabled:opacity-60"
          >
            {loading ? (
              <span className="size-6 animate-spin rounded-full border-2 border-player/30 border-t-player" />
            ) : (
              <span className="ml-1 text-2xl">▶</span>
            )}
          </button>
          {error && <p className="mt-4 max-w-sm px-4 text-sm text-player-muted">{error}</p>}
        </div>
      )}
      {state === "active" && (
        <div className="relative text-center">
          <StatusBadge status="Recording" />
          <p className="mt-5 font-mono text-4xl font-semibold">{elapsed ?? "01:42:18"}</p>
          <p className="mt-2 text-sm text-player-muted">
            {t("Playback will be available after the livestream ends.")}
          </p>
        </div>
      )}
      {state === "processing" && (
        <div className="relative text-center">
          <span className="mx-auto block size-8 animate-spin rounded-full border-2 border-player-muted border-t-player-foreground" />
          <p className="mt-5 font-medium">{t("Finalizing your recording")}</p>
          <p className="mt-2 text-sm text-player-muted">
            {t("Playback will be available when processing is complete.")}
          </p>
        </div>
      )}
      {state === "failed" && (
        <div className="relative max-w-md text-center">
          <AlertTriangle className="mx-auto size-8 text-recording" />
          <p className="mt-4 font-medium">{t("Recording couldn’t be completed")}</p>
          <p className="mt-2 text-sm text-player-muted">
            {failedDetail ?? "47 minutes were saved before the stream connection was lost."}
          </p>
        </div>
      )}
    </div>
  );
}
function LimitChannelRow({ channel }: { channel: ChannelModel }) {
  const c = useChannelControls(channel);
  if (c.removed) return null;
  return (
    <div className="flex items-center gap-3 border-b px-3.5 py-3 last:border-b-0">
      <CreatorAvatar channel={channel} size="sm" />
      <b className="min-w-0 flex-1 truncate text-sm">{channel.handle}</b>
      <StatusBadge status={c.on ? channel.status : "Paused"} />
      {channel.status !== "Recording" && (
        <Button
          size="sm"
          variant="ghost"
          className="text-destructive hover:bg-destructive/10 hover:text-destructive"
          onClick={() => c.openRemove()}
        >
          Remove
        </Button>
      )}
      {c.dialogs}
    </div>
  );
}

export function ChannelLimitMeter({
  used,
  limit,
  className,
}: {
  used: number;
  limit: number;
  className?: string;
}) {
  const percent = limit > 0 ? Math.min(100, Math.round((used / limit) * 100)) : 0;
  return (
    <div
      className={cn("flex flex-col gap-1.5", className)}
      aria-label={`Channel limit: ${used} of ${limit} used`}
    >
      <div className="flex items-center justify-between text-xs">
        <span className="font-bold text-muted-foreground">Channel limit</span>
        <span className="font-mono font-bold">
          {used} / {limit}
        </span>
      </div>
      <div className="h-2 overflow-hidden rounded-full bg-surface-3">
        <span
          className={cn(
            "block h-full rounded-full",
            percent >= 100 ? "bg-warning" : "bg-gradient-to-r from-primary to-accent",
          )}
          style={{ width: `${percent}%` }}
        />
      </div>
    </div>
  );
}

export function AddChannelDialog({
  trigger,
  initialInput = "",
  open: controlledOpen,
  onOpenChange,
}: {
  trigger?: ReactNode;
  initialInput?: string;
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
}) {
  const navigate = useNavigate();
  const { t } = usePreferences();
  const { query: channelsQuery } = useChannelsData();
  const { query: entitlementQuery } = useEntitlementData(!isDemoMode);
  const createChannel = useCreateChannelMutation();
  const [uncontrolledOpen, setUncontrolledOpen] = useState(false);
  const open = controlledOpen ?? uncontrolledOpen;
  const setOpen = (next: boolean) => {
    if (controlledOpen === undefined) setUncontrolledOpen(next);
    onOpenChange?.(next);
  };
  const [input, setInput] = useState(initialInput);
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
  const entitlement = entitlementQuery.data;
  const { query: publicPricingQuery } = usePublicPricingData();
  const isFree = isDemoMode || entitlement?.plan === "free";
  const [autoRecord, setAutoRecord] = useState(true);
  const channelLimit =
    entitlement?.limits.max_watches ?? publicPricingQuery.data?.free_max_channels_per_user ?? null;
  const preview = useCreatorPreview(open && parsed ? parsed.source : null);
  const previewCreator =
    preview.data && parsed && preview.data.creator ? preview.data.creator : null;
  const previewMissing =
    Boolean(parsed) && (preview.isError || (preview.data !== undefined && !preview.data.creator));

  useEffect(() => {
    if (open) setInput((current) => current || initialInput);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  useEffect(() => {
    if (state === "limit") return;
    setErrorText(null);
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
    // `state` only guards the limit panel; re-running on it would loop.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [channelItems, input, parsed]);

  const reset = () => {
    setInput("");
    setState("idle");
    setPhase("form");
    setCreatedWatchId(null);
    setDuplicateWatchId(null);
    setQuotaLimit(null);
    setErrorText(null);
    setAutoRecord(true);
  };

  const submit = async () => {
    if (state !== "found" || !parsed) return;
    setPhase("submitting");
    setErrorText(null);
    try {
      const watch = await createChannel.mutateAsync({
        source: parsed.source,
        auto_record: !isFree && autoRecord,
      });
      setCreatedWatchId(watch.id);
      setPhase("success");
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

  const usedSlots = channelItems.length;
  const limitForPanel = quotaLimit ?? channelLimit ?? usage.channels.limit;
  const previewInitials = (previewCreator?.display_name || name)
    .split(" ")
    .map((word) => word[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  let body: ReactNode;
  if (phase === "success") {
    const recordsAutomatically = !isFree && autoRecord;
    body = (
      <div className="flex flex-col items-center gap-4 py-4 text-center">
        <div className="relative">
          <AvatarCircle
            src={previewCreator?.avatar_url}
            initials={previewInitials}
            tone="from-avatar-one to-avatar-one-end"
            size="xl"
          />
          <span className="absolute -bottom-1 -right-1 grid size-7 place-items-center rounded-full border-[3px] border-surface bg-success text-white">
            <Check className="size-3.5" strokeWidth={3} />
          </span>
        </div>
        <DialogTitle className="text-xl font-extrabold">{handle} is being watched</DialogTitle>
        <DialogDescription className="max-w-[360px] text-sm text-muted-foreground">
          {recordsAutomatically
            ? "We’ll start recording about a minute after the LIVE begins on our servers — nothing to keep open."
            : isFree
              ? `${freeWebSentence(publicPricingQuery.data, entitlement?.limits.max_watches)} Automatic recording unlocks after you buy credits; then turn on Auto-record on the channel page.`
              : "Auto-record is off. Turn it on from the channel page whenever you want LIVEs recorded."}
        </DialogDescription>
        <div className="flex flex-wrap justify-center gap-2">
          <StatusBadge status="Waiting" />
          <span
            className={cn(
              "inline-flex h-6 items-center rounded-full px-2.5 text-xs font-bold",
              recordsAutomatically
                ? "bg-success-subtle text-success"
                : "bg-surface-2 text-muted-foreground",
            )}
          >
            {recordsAutomatically ? "Auto-record on" : "Auto-record off"}
          </span>
          {channelLimit !== null && (
            <span className="inline-flex h-6 items-center rounded-full bg-surface-2 px-2.5 text-xs font-bold text-muted-foreground">
              {Math.min(usedSlots, channelLimit)} of {channelLimit} slots used
            </span>
          )}
        </div>
        <div className="mt-1.5 flex flex-col-reverse gap-2 sm:flex-row">
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
            {t("Open channel")}
          </Button>
        </div>
      </div>
    );
  } else if (state === "limit") {
    body = (
      <div className="flex flex-col gap-5">
        <div className="flex items-center gap-3.5">
          <span className="grid size-12 shrink-0 place-items-center rounded-[14px] bg-warning-subtle text-warning">
            <AlertTriangle className="size-6" />
          </span>
          <div className="space-y-1">
            <DialogTitle className="text-xl font-extrabold">
              All {limitForPanel} channel slots are in use
            </DialogTitle>
            <DialogDescription className="text-sm text-muted-foreground">
              Remove a channel to add a new one.
            </DialogDescription>
          </div>
        </div>
        <ChannelLimitMeter
          used={Math.max(channelItems.length, limitForPanel)}
          limit={limitForPanel}
        />
        <div className="overflow-hidden rounded-[14px] border">
          {channelItems.map((channel) => (
            <LimitChannelRow key={channel.id} channel={channel} />
          ))}
        </div>
        <p className="text-xs text-muted-foreground">
          Removing a channel stops monitoring it. Its recordings stay in your library until you
          delete them or they expire.
        </p>
        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button asChild variant="ghost">
            <Link to="/contact" onClick={() => setOpen(false)}>
              Need more? Contact us
            </Link>
          </Button>
          <Button
            onClick={() => {
              setQuotaLimit(null);
              setState(parsed ? "found" : "idle");
              void channelsQuery.refetch();
            }}
          >
            Try again
          </Button>
        </div>
      </div>
    );
  } else {
    const inputTone =
      state === "invalid" ? "err" : state === "found" && !previewMissing ? "ok" : undefined;
    body = (
      <div className="flex flex-col gap-5">
        <div className="space-y-1.5 pr-6">
          <DialogTitle className="text-xl font-extrabold">{t("Add a channel")}</DialogTitle>
          <DialogDescription className="text-sm text-muted-foreground">
            We check the channel around the clock. Monitoring is free — only recording uses credits.
          </DialogDescription>
        </div>
        <div className="space-y-1.5">
          <label htmlFor="add-channel-input" className="text-sm font-semibold">
            {t("TikTok username or profile link")}
          </label>
          <div className="relative">
            <span className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 font-bold text-muted-foreground">
              @
            </span>
            <Input
              id="add-channel-input"
              autoFocus
              value={input}
              onChange={(event) => setInput(event.target.value)}
              aria-invalid={state === "invalid"}
              aria-describedby="add-channel-help"
              placeholder="username or tiktok.com/@username"
              className={cn(
                "h-12 pl-8 pr-10 text-base",
                inputTone === "ok" && "border-success focus-visible:ring-success/25",
                inputTone === "err" && "border-destructive focus-visible:ring-destructive/25",
              )}
            />
            {phase === "submitting" ? (
              <span
                aria-label={t("Adding channel…")}
                className="absolute right-3.5 top-1/2 size-4 -translate-y-1/2 animate-spin rounded-full border-2 border-muted-foreground border-t-transparent"
              />
            ) : (
              inputTone === "ok" && (
                <Check
                  className="absolute right-3.5 top-1/2 size-[18px] -translate-y-1/2 text-success"
                  strokeWidth={2.6}
                />
              )
            )}
          </div>
          <p id="add-channel-help" className="text-xs">
            {state === "invalid" ? (
              <span className="flex items-center gap-1.5 font-semibold text-destructive">
                <AlertTriangle className="size-3.5" />
                Enter a valid TikTok username or profile link.
              </span>
            ) : state === "found" && previewMissing ? (
              <span className="font-semibold text-warning-foreground">
                We couldn’t load this profile right now. Check the spelling — you can still add it.
              </span>
            ) : state === "found" && previewCreator ? (
              <span className="font-semibold text-success">Channel found</span>
            ) : (
              <span className="text-muted-foreground">
                Accepted: <span className="font-mono">@username</span>,{" "}
                <span className="font-mono">username</span> or{" "}
                <span className="font-mono">tiktok.com/@username</span>.
              </span>
            )}
          </p>
        </div>
        {state === "found" && parsed && (
          <div className="flex items-center gap-3.5 rounded-[14px] border bg-surface-2 p-4">
            <AvatarCircle
              src={previewCreator?.avatar_url}
              initials={previewInitials}
              tone="from-avatar-one to-avatar-one-end"
              size="lg"
            />
            <div className="min-w-0 flex-1">
              <p className="truncate font-bold">{previewCreator?.display_name || name}</p>
              <p className="truncate text-sm text-muted-foreground">{parsed.handle}</p>
            </div>
            {preview.data?.live_status === "live" ? (
              <span className="inline-flex h-6 items-center gap-1.5 rounded-full bg-recording-subtle px-2.5 text-xs font-bold text-live-ink">
                <span className="size-1.5 animate-pulse rounded-full bg-current" />
                LIVE
              </span>
            ) : preview.data?.live_status === "offline" ? (
              <StatusBadge status="Offline" />
            ) : (
              <PlatformBadge />
            )}
          </div>
        )}
        {state === "found" && (
          <div className="flex items-center justify-between gap-4">
            <span>
              <b className="block text-sm">Auto-record when live</b>
              <span className="text-xs text-muted-foreground">
                {isFree ? "Available after you buy credits." : "Uses credits only while recording."}
              </span>
            </span>
            <Switch
              checked={!isFree && autoRecord}
              disabled={isFree}
              onCheckedChange={setAutoRecord}
              aria-label="Auto-record when live"
            />
          </div>
        )}
        {(state === "exists" || state === "unavailable") && (
          <StateBanner
            tone={state === "exists" ? "info" : "warning"}
            title={
              state === "exists"
                ? "This channel is already monitored"
                : "We couldn’t add this channel"
            }
            body={
              state === "exists"
                ? "It’s in your channel list. Open it to change monitoring."
                : (errorText ?? "SaveStream could not complete the request. Try again.")
            }
            action={
              state === "exists" ? (
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => {
                    setOpen(false);
                    if (duplicateWatchId) {
                      void navigate({ to: "/channels/$id", params: { id: duplicateWatchId } });
                    } else {
                      void navigate({ to: "/channels" });
                    }
                  }}
                >
                  Open channel
                </Button>
              ) : (
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
              )
            }
          />
        )}
        <p className="flex items-start gap-2 rounded-[12px] bg-primary-subtle px-3 py-2.5 text-xs text-accent-ink">
          <ShieldCheck className="mt-px size-4 shrink-0" />
          <span>
            Only add channels you own, manage, or have permission to record (
            <Link to="/acceptable-use" className="font-semibold underline-offset-2 hover:underline">
              Acceptable Use Policy
            </Link>
            ).
          </span>
        </p>
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
        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button variant="ghost" onClick={() => setOpen(false)}>
            {t("Cancel")}
          </Button>
          <Button
            onClick={() => void submit()}
            disabled={state !== "found" || phase === "submitting"}
          >
            {phase === "submitting" ? (
              <>
                <span className="size-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
                {t("Adding")}…
              </>
            ) : (
              t("Add channel")
            )}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(nextOpen) => {
        setOpen(nextOpen);
        if (!nextOpen) setTimeout(reset, 200);
      }}
    >
      {controlledOpen === undefined && (
        <DialogTrigger asChild>
          {trigger || (
            <Button>
              <Plus />
              {t("Add channel")}
            </Button>
          )}
        </DialogTrigger>
      )}
      <DialogContent className="inset-0 top-0 h-dvh max-w-none translate-x-0 translate-y-0 content-start overflow-y-auto rounded-none p-6 sm:inset-auto sm:left-[50%] sm:top-[50%] sm:h-auto sm:max-w-[540px] sm:translate-x-[-50%] sm:translate-y-[-50%] sm:rounded-[20px] sm:p-7">
        {body}
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
            <span className="font-mono">{fileSize}</span> /{" "}
            <span className="font-mono">{remaining}</span>. {t("Quota resets on")}{" "}
            {formatDate(usage.resetsOn, language)}.
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
      onClick={() => void notificationStore.markRead(n.id)}
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
  const pending = pauseChannel.isPending || resumeChannel.isPending || deleteChannel.isPending;

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
      className={cn(
        "flex flex-col gap-3.5 rounded-[14px] border px-[18px] py-3.5 sm:flex-row sm:items-start",
        styles,
      )}
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
/** Password input with a show/hide toggle. */
export function PasswordInput({ className, ...props }: Omit<ComponentProps<typeof Input>, "type">) {
  const { t } = usePreferences();
  const [visible, setVisible] = useState(false);
  const Icon = visible ? EyeOff : Eye;
  const invalid = props["aria-invalid"] === true || props["aria-invalid"] === "true";
  return (
    <div className={cn("relative", className)}>
      <Input
        {...props}
        type={visible ? "text" : "password"}
        className={cn("pr-10", invalid && "border-destructive focus-visible:ring-destructive")}
      />
      <button
        type="button"
        onClick={() => setVisible((v) => !v)}
        className="absolute inset-y-0 right-0 grid w-10 place-items-center rounded-r-md text-muted-foreground hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        aria-label={t(visible ? "Hide password" : "Show password")}
        aria-pressed={visible}
        aria-controls={props.id}
      >
        <Icon className="size-4" />
      </button>
    </div>
  );
}

export function PasswordField({
  label = "Password",
  id,
  value,
  onChange,
  showStrength = false,
  autoComplete = "new-password",
  error,
}: {
  label?: string;
  id: string;
  value: string;
  onChange: (v: string) => void;
  showStrength?: boolean;
  autoComplete?: string;
  error?: string | null | undefined;
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
      <PasswordInput
        id={id}
        className="mt-2"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder="Password"
        autoComplete={autoComplete}
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? `${id}-error` : undefined}
      />
      {error && (
        <p id={`${id}-error`} className="mt-1.5 text-xs text-destructive">
          {t(error)}
        </p>
      )}
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
