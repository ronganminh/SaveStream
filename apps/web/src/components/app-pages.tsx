import { Link, useNavigate, useParams, useSearch } from "@tanstack/react-router";
import {
  formatRecordingTime as formatHoursLeft,
  useCreditSummary,
} from "@/components/app/shell-extras";
import {
  useNotificationPreferencesData,
  useUpdateNotificationPreferencesMutation,
} from "@/hooks/use-notifications";
import { toast } from "sonner";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  useEffect,
  useState,
  type ComponentProps,
  type ElementType,
  type FormEvent,
  type ReactNode,
} from "react";
import {
  Activity,
  AlertCircle,
  AlertTriangle,
  Apple,
  ArrowLeft,
  ArrowRight,
  ArrowUpDown,
  RotateCcw,
  ExternalLink,
  Bell,
  Calendar,
  Check,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  Clock3,
  Cloud,
  CreditCard,
  Download,
  FileVideo,
  Filter,
  Gauge,
  Grid2X2,
  HardDrive,
  KeyRound,
  List,
  LockKeyhole,
  Mail,
  Menu,
  Monitor,
  MoreHorizontal,
  Pause,
  Play,
  Plus,
  Radio,
  Search,
  Send,
  Server,
  Settings,
  ShieldCheck,
  SlidersHorizontal,
  Sparkles,
  Trash2,
  Upload,
  UserRound,
  Users,
  Video,
  Wifi,
  XCircle,
  Zap,
  Gift,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import { dailyRecordingHours, usage, user } from "@/mocks/fixtures";
import {
  ActiveRecordingCard,
  AddChannelDialog,
  AvatarCircle,
  AdminHealthBadge,
  AppShell,
  ChannelCard,
  ChannelGridCard,
  ChannelLimitMeter,
  ChannelRow,
  ConfirmDeleteDialog,
  ConfirmDialog,
  CreatorAvatar,
  Pill,
  RecordingCreatorAvatar,
  EmptyState,
  ErrorState,
  FilterBar,
  Logo,
  PageHeader,
  PasswordField,
  PasswordInput,
  PlanCard,
  PlatformBadge,
  PrototypeStateBar,
  RecordingCard,
  RecordingRow,
  SearchInput,
  StatCard,
  StateBanner,
  StatusBadge,
  SuccessState,
  ThemeMenu,
  UpgradeDialog,
  UsageProgress,
  VideoPlayerShell,
} from "@/components/app-components";
import { AdminGlobalSearch, AdminOwnerAccessPanel } from "@/components/admin/foundation";
import { PayPalCheckoutButtons } from "@/components/paypal-checkout";
import { cn } from "@/lib/utils";
import { usePreferences, type Language } from "@/lib/preferences";
import { sampleMedia, type SampleMediaItem } from "@/lib/sample-media";
import {
  planCatalog,
  planList,
  planLimitDefinitions,
  planMediaFootnote,
} from "@/mocks/demo-plan-catalog";
import { formatCurrencyUsd, formatDate, pluralize } from "@/lib/formatters";
import { isAdminRole, isDemoMode } from "@/lib/app-config";
import { ProductionLanding } from "@/components/public/landing";
import {
  freeWebSentence,
  packHours,
  packPricePerHour,
  recommendPack,
  retentionFeature,
  retentionSentence,
} from "@/lib/plan-facts";
import { authApi, authErrorMessage, isExpiredLinkError } from "@/api/auth";
import {
  AuthCardLayout,
  AuthSplitLayout,
  IconTile,
  ONE_TIME_LINK_MINUTES,
  OrDivider,
  PasswordChecklist,
  SocialButton,
  useTrialMinutesLabel,
} from "@/components/auth/auth-ui";
import { RestoringSessionScreen } from "@/components/system/system-pages";
import { ApiError } from "@/api/errors";
import {
  firebaseSocialConfigured,
  socialProviderErrorMessage,
  type SocialProvider,
} from "@/lib/firebase-social-login";
import type {
  CreditPackageResponse,
  CreditReservationResponse,
  CreditTransactionResponse,
  Money,
  PaymentOrderResponse,
  PaymentStatusValue,
  PricingResponse,
  PublicPricingResponse,
  PublicRecordingRate,
} from "@/api/types";
import { useAuth } from "@/auth/auth-context";
import { PUBLIC_SITE_URL } from "@/lib/route-metadata";
import {
  useChannelData,
  useChannelsData,
  useCreditBalanceData,
  useCreditPackagesData,
  useCreditReservationsData,
  useCreditTransactionsData,
  useEntitlementData,
  usePaymentOrdersData,
  usePricingData,
  usePublicPricingData,
  useCheckoutChannels,
  useRecordingArtifactsData,
  useRecordingData,
  useRecordingsData,
  useUsageData,
  useCreatorPreview,
} from "@/hooks/use-domain-data";
import {
  channelActionErrorMessage,
  existingWatchId,
  useCreateChannelMutation,
  useDeleteChannelMutation,
  usePauseChannelMutation,
  useUpdateChannelMutation,
  useResumeChannelMutation,
} from "@/hooks/use-channel-mutations";
import type { ChannelModel, ChannelStatus, RecordingModel, Status } from "@/repositories";
import { displayNameFromTikTokUsername, parseTikTokSource } from "@/lib/tiktok-source";
import { currentLegalConsent } from "@/lib/legal";
import {
  artifactActionErrorMessage,
  recordingActionErrorMessage,
  useDeleteRecordingMutation,
  useRecordingDownloadMutation,
  useStopRecordingMutation,
} from "@/hooks/use-recording-mutations";
import { useRecordingDownload } from "@/hooks/use-recording-download";
import { useRecordingRealtime, type RecordingRealtimeState } from "@/hooks/use-recording-realtime";
import { useAdminOperationalSnapshotData } from "@/hooks/use-admin-data";
import {
  billingActionErrorMessage,
  isAwaitingPaymentConfirmation,
  useBillingCheckoutMutation,
  usePayPalCaptureMutation,
  type BillingCheckoutInput,
} from "@/hooks/use-billing";

export { meta, publicMeta } from "@/components/app-components";

const publicLinks = [
  { href: "/#features", label: "Features" },
  { href: "/#how", label: "How it works" },
  { href: "/#examples", label: "Examples" },
  { to: "/pricing", label: "Pricing" },
  { to: "/help", label: "Help" },
] as const;
const navLinkClass =
  "rounded-[10px] px-2.5 py-2 text-[15px] font-medium text-muted-foreground transition-colors hover:bg-surface-2 hover:text-foreground";
export function PublicHeader() {
  const { t } = usePreferences();
  const { status } = useAuth();
  const authenticated = status === "authenticated";
  return (
    <header className="fixed inset-x-0 top-0 z-[var(--z-sticky)] border-b bg-background/85 backdrop-blur-md backdrop-saturate-150">
      <div className="mx-auto flex h-[72px] max-w-[1240px] items-center gap-2 px-4 sm:px-6">
        <Logo />
        <nav aria-label={t("Main")} className="ml-6 hidden items-center gap-0.5 lg:flex">
          {publicLinks.map((link) =>
            "to" in link ? (
              <Link
                key={link.label}
                to={link.to}
                className={navLinkClass}
                activeProps={{ className: "font-semibold text-foreground", "aria-current": "page" }}
              >
                {t(link.label)}
              </Link>
            ) : (
              <a key={link.label} href={link.href} className={navLinkClass}>
                {t(link.label)}
              </a>
            ),
          )}
        </nav>
        <div className="ml-auto flex min-w-0 items-center gap-0.5 sm:gap-1">
          <ThemeMenu />
          {authenticated ? (
            <>
              <Button variant="ghost" asChild className="hidden md:inline-flex">
                <Link to="/overview">{t("Overview")}</Link>
              </Button>
              <Button asChild className="hidden md:inline-flex">
                <Link to="/billing">
                  <CreditCard />
                  {t("Buy credits")}
                </Link>
              </Button>
            </>
          ) : status === "guest" ? (
            <>
              <Button variant="ghost" asChild className="hidden md:inline-flex">
                <Link to="/sign-in">{t("Sign in")}</Link>
              </Button>
              <Button asChild className="hidden sm:inline-flex">
                <Link to="/sign-up">{t("Sign up")}</Link>
              </Button>
            </>
          ) : null}
        </div>
        <div className="lg:hidden">
          <Sheet>
            <SheetTrigger asChild>
              <Button variant="ghost" size="icon" aria-label={t("Open menu")}>
                <Menu />
              </Button>
            </SheetTrigger>
            <SheetContent className="w-[min(22rem,90vw)]">
              <SheetHeader>
                <SheetTitle>
                  <Logo />
                </SheetTitle>
                <SheetDescription className="sr-only">{t("Public navigation")}</SheetDescription>
              </SheetHeader>
              <nav className="mt-8 flex flex-col gap-1">
                {publicLinks.map((link) =>
                  "to" in link ? (
                    <Button key={link.label} variant="ghost" className="justify-start" asChild>
                      <Link to={link.to}>{t(link.label)}</Link>
                    </Button>
                  ) : (
                    <Button key={link.label} variant="ghost" className="justify-start" asChild>
                      <a href={link.href}>{t(link.label)}</a>
                    </Button>
                  ),
                )}
              </nav>
              <div className="mt-6 grid gap-2 border-t pt-6">
                {authenticated ? (
                  <>
                    <Button variant="outline" asChild>
                      <Link to="/overview">{t("Overview")}</Link>
                    </Button>
                    <Button asChild>
                      <Link to="/billing">
                        <CreditCard />
                        {t("Buy credits")}
                      </Link>
                    </Button>
                  </>
                ) : status === "guest" ? (
                  <>
                    <Button variant="outline" asChild>
                      <Link to="/sign-in">{t("Sign in")}</Link>
                    </Button>
                    <Button asChild>
                      <Link to="/sign-up">{t("Sign up")}</Link>
                    </Button>
                  </>
                ) : null}
              </div>
            </SheetContent>
          </Sheet>
        </div>
      </div>
    </header>
  );
}

function formatSampleDuration(seconds?: number) {
  if (!seconds) return "—";
  const total = Math.max(0, Math.round(seconds));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const remaining = total % 60;
  if (total < 60) return `0:${String(remaining).padStart(2, "0")}`;
  return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m ${remaining}s`;
}

export function RecordingExamples() {
  const { t } = usePreferences();
  const { status } = useAuth();
  const authenticated = status === "authenticated";
  const recordingCtaTo = authenticated ? "/channels" : "/sign-up";
  const [selected, setSelected] = useState<SampleMediaItem | null>(null);

  return (
    <section id="examples" className="scroll-mt-16 border-b bg-surface-subtle py-20">
      <div className="mx-auto max-w-6xl px-4">
        <div className="max-w-xl">
          <p className="text-sm font-semibold text-primary">{t("Completed recordings")}</p>
          <h2 className="mt-2 text-3xl font-semibold">{t("Recording Examples")}</h2>
          <p className="mt-3 text-muted-foreground">
            {t("Real livestreams recorded by SaveStream, shared with the creators’ permission.")}
          </p>
        </div>

        <div className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {sampleMedia.map((item, index) => (
            <button
              key={item.id}
              type="button"
              onClick={() => setSelected(item)}
              className="group overflow-hidden rounded-lg border bg-surface text-left shadow-sm transition hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-dashboard focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
              aria-label={`${t("Watch sample recording")} ${index + 1}`}
            >
              <div className="relative aspect-[9/16] overflow-hidden bg-black">
                <img
                  src={item.thumbnailUrl}
                  alt=""
                  loading="lazy"
                  className="h-full w-full object-cover transition duration-300 group-hover:scale-[1.02]"
                />
                <span className="absolute inset-0 bg-gradient-to-t from-black/55 via-transparent to-black/5" />
                <span className="absolute left-3 top-3 rounded-md border border-white/15 bg-black/60 px-2 py-1 text-[10px] font-medium text-white">
                  {t("SAMPLE")}
                </span>
                <span className="absolute left-1/2 top-1/2 grid size-11 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full bg-white text-black shadow-lg transition group-hover:scale-105">
                  <Play className="ml-0.5 size-4 fill-current" />
                </span>
                <span className="absolute bottom-3 right-3 rounded bg-black/70 px-1.5 py-0.5 font-mono text-[10px] text-white">
                  {t("Preview")} {formatSampleDuration(item.durationSeconds)}
                </span>
              </div>
              <div className="p-4">
                <div className="flex min-w-0 items-center justify-between gap-3">
                  <p className="truncate text-sm font-semibold">
                    {t("Sample")} {String(index + 1).padStart(2, "0")}
                  </p>
                  <StatusBadge status="Ready" />
                </div>
                <p className="mt-1 text-sm text-muted-foreground">{item.title}</p>
                <div className="mt-4 flex items-center justify-between border-t pt-3 text-xs text-muted-foreground">
                  <span>{t("Full recording")}</span>
                  <span className="font-mono">
                    {formatSampleDuration(item.sourceDurationSeconds ?? item.durationSeconds)}
                  </span>
                </div>
              </div>
            </button>
          ))}
        </div>

        <div className="mt-10 text-center">
          <Button
            size="lg"
            asChild
            className="h-auto max-w-full whitespace-normal px-4 py-2 text-center sm:px-8"
          >
            <Link to={recordingCtaTo}>
              {t(authenticated ? "Open your channels" : "Start recording your own livestreams")}
              <ArrowRight />
            </Link>
          </Button>
        </div>
      </div>

      <Dialog
        open={Boolean(selected)}
        onOpenChange={(open) => {
          if (!open) setSelected(null);
        }}
      >
        <DialogContent className="max-w-4xl">
          <DialogHeader>
            <div className="mb-1 flex items-center gap-2">
              <span className="rounded-md bg-primary-subtle px-2 py-1 text-[10px] font-semibold uppercase text-primary">
                {t("Sample recording")}
              </span>
              <StatusBadge status="Ready" />
            </div>
            <DialogTitle>{selected?.title}</DialogTitle>
            <DialogDescription>
              {t("Recorded by SaveStream and shared with the creator’s permission.")}
            </DialogDescription>
          </DialogHeader>

          <div className="overflow-hidden rounded-lg bg-black">
            {selected && (
              <video
                key={selected.id}
                className="mx-auto max-h-[68vh] w-full object-contain"
                controls
                autoPlay
                playsInline
                preload="metadata"
                poster={selected.thumbnailUrl}
              >
                <source src={selected.mediaUrl} type="video/mp4" />
              </video>
            )}
          </div>

          <div className="grid grid-cols-3 gap-px overflow-hidden rounded-lg border bg-border text-sm">
            {[
              [t("Preview clip"), formatSampleDuration(selected?.durationSeconds)],
              [
                t("Full recording"),
                formatSampleDuration(selected?.sourceDurationSeconds ?? selected?.durationSeconds),
              ],
              [
                t("Original resolution"),
                selected
                  ? `${selected.sourceWidth ?? selected.width}×${selected.sourceHeight ?? selected.height}`
                  : "—",
              ],
            ].map(([label, value]) => (
              <div key={label} className="bg-surface p-3">
                <p className="text-xs text-muted-foreground">{label}</p>
                <p className="mt-1 font-mono font-medium">{value}</p>
              </div>
            ))}
          </div>

          <DialogFooter>
            <Button asChild>
              <Link to={recordingCtaTo}>
                {t(authenticated ? "Open your channels" : "Start recording your own")}
              </Link>
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </section>
  );
}

function RecordingPreviewCard() {
  return (
    <div className="flex flex-col gap-3 rounded-lg border bg-background p-4 text-left sm:flex-row sm:items-center sm:justify-between">
      <div className="flex items-center gap-3">
        <span className="grid size-10 place-items-center rounded-full bg-primary-subtle text-sm font-semibold text-primary">
          YC
        </span>
        <div>
          <p className="text-sm font-medium">@yourchannel</p>
          <p className="text-xs text-muted-foreground">
            Recording in the cloud · started automatically
          </p>
        </div>
      </div>
      <div className="flex items-center gap-2 text-xs font-medium">
        <span className="size-2 animate-pulse rounded-full bg-recording" />
        <span className="font-mono">LIVE · 00:42:18</span>
      </div>
    </div>
  );
}

export function LandingPage() {
  if (!isDemoMode) return <ProductionLanding />;
  return <DemoLandingPage />;
}

function DemoLandingPage() {
  const { t, language } = usePreferences();
  const { query: publicPricingQuery } = usePublicPricingData();
  const publicPricing = publicPricingQuery.data;
  const { status } = useAuth();
  const authenticated = status === "authenticated";
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "SaveStream",
    applicationCategory: "MultimediaApplication",
    operatingSystem: "Web",
    url: PUBLIC_SITE_URL,
    description: isDemoMode
      ? "Frontend preview for authorized livestream recording workflows."
      : "Cloud monitoring and recording for authorized TikTok livestream workflows.",
  };
  return (
    <div className="min-h-screen bg-background">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />
      <PublicHeader />
      <main>
        <section className="overflow-hidden border-b pb-20 pt-32">
          <div className="mx-auto max-w-7xl px-4 text-center sm:px-6">
            <span className="inline-flex items-center gap-2 rounded-full border bg-surface-subtle px-3 py-1 text-xs text-muted-foreground">
              <Cloud className="size-3 text-primary" />
              {t("Automatic cloud recording")}
            </span>
            {isDemoMode && (
              <p className="mx-auto mt-3 w-fit rounded-md border border-warning/30 bg-warning-subtle px-3 py-1 text-xs text-warning-foreground">
                {t("Product preview — backend recording services are not connected.")}
              </p>
            )}
            <h1 className="mx-auto mt-6 max-w-4xl text-4xl font-semibold tracking-normal sm:text-6xl">
              {t("Automatic TikTok livestream recording in the cloud.")}
            </h1>
            <p className="mx-auto mt-6 max-w-2xl text-lg leading-8 text-muted-foreground">
              {t(
                isDemoMode
                  ? "SaveStream is designed to monitor authorized channels and automate cloud recording. This public build is a frontend demo; backend recording services are not connected."
                  : "SaveStream watches the TikTok channels you are authorized to record and saves every livestream in the cloud. No computer or browser needs to stay open.",
              )}
            </p>
            <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
              <Button size="lg" asChild>
                <Link to={authenticated ? "/overview" : "/sign-up"}>
                  {t(authenticated ? "Open dashboard" : "Start for free")}
                  <ArrowRight />
                </Link>
              </Button>
              <Button size="lg" variant="outline" asChild>
                <a href="#how">{t("See how it works")}</a>
              </Button>
            </div>
            <p className="mt-3 text-xs text-muted-foreground">
              {t(
                authenticated
                  ? "Continue in your SaveStream workspace."
                  : "No credit card required.",
              )}
            </p>
            <div className="relative mx-auto mt-16 max-w-6xl overflow-hidden rounded-xl border bg-surface p-2 shadow-dashboard">
              <div className="flex h-10 items-center gap-2 border-b px-3">
                <span className="size-2.5 rounded-full bg-border" />
                <span className="size-2.5 rounded-full bg-border" />
                <span className="size-2.5 rounded-full bg-border" />
                <span className="mx-auto min-w-0 max-w-[calc(100%-4.5rem)] truncate rounded border bg-background px-3 py-1 text-[9px] text-muted-foreground sm:px-20">
                  savestream.online/overview
                </span>
              </div>
              <div className="grid text-left md:grid-cols-[180px_1fr]">
                <div className="hidden border-r p-4 md:block">
                  <Logo />
                  <div className="mt-8 space-y-2">
                    {["Overview", "Channels", "Recordings", "Usage & Billing"].map((x, i) => (
                      <div
                        key={x}
                        className={cn(
                          "rounded px-3 py-2 text-xs",
                          i === 0 ? "bg-accent font-medium" : "text-muted-foreground",
                        )}
                      >
                        {t(x)}
                      </div>
                    ))}
                  </div>
                </div>
                <div className="p-4 sm:p-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-lg font-semibold">{t("Overview")}</p>
                      <p className="text-xs text-muted-foreground">
                        {t("Your recording workspace")}
                      </p>
                    </div>
                    <Button size="sm">
                      <Plus />
                      {t("Add channel")}
                    </Button>
                  </div>
                  <div className="mt-5 grid grid-cols-1 border-l border-t sm:grid-cols-3">
                    {isDemoMode ? (
                      <>
                        <StatCard
                          label="Recording hours"
                          value="12.6 / 50 h"
                          detail="25% used"
                          icon={Clock3}
                          progress={25}
                        />
                        <StatCard
                          label="Active channels"
                          value="3 / 5"
                          detail="3 monitoring"
                          icon={Radio}
                        />
                        <StatCard
                          label="Stored"
                          value="18.4 GB"
                          detail="4 recordings"
                          icon={HardDrive}
                        />
                      </>
                    ) : (
                      <>
                        <StatCard
                          label={t("Channels monitored")}
                          value="3"
                          detail={t("Checked automatically")}
                          icon={Radio}
                        />
                        <StatCard
                          label={t("Credits available")}
                          value="2,480"
                          detail={t("About 41 hours of recording")}
                          icon={CreditCard}
                        />
                        <StatCard
                          label={t("Recordings")}
                          value="12"
                          detail={t("Ready to watch or download")}
                          icon={FileVideo}
                        />
                      </>
                    )}
                  </div>
                  <div className="mt-5">
                    {isDemoMode ? <ActiveRecordingCard /> : <RecordingPreviewCard />}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
        <section id="how" className="border-b py-20">
          <div className="mx-auto max-w-6xl px-4">
            <p className="text-sm font-semibold text-primary">{t("How it works")}</p>
            <h2 className="mt-2 text-3xl font-semibold">{t("Set it once. We handle the rest.")}</h2>
            <div className="mt-10 grid gap-px overflow-hidden rounded-lg border bg-border md:grid-cols-4">
              {[
                [Plus, "Add a channel", "Enter a TikTok username or profile URL."],
                [
                  Radio,
                  "We monitor it",
                  "SaveStream checks the channel’s live status from the cloud, around the clock.",
                ],
                [
                  Video,
                  "Recording starts",
                  "Recording starts automatically when the channel goes live.",
                ],
                [Play, "Watch later", "Play or download when it’s ready."],
              ].map(([I, stepTitle, b], i) => (
                <div className="bg-background p-6" key={String(stepTitle)}>
                  <span className="font-mono text-xs text-muted-foreground">0{i + 1}</span>
                  {I
                    ? (() => {
                        const Icon = I;
                        return <Icon className="mt-8 size-5 text-primary" />;
                      })()
                    : null}
                  <h3 className="mt-4 font-medium">{t(String(stepTitle))}</h3>
                  <p className="mt-2 text-sm leading-6 text-muted-foreground">{t(String(b))}</p>
                </div>
              ))}
            </div>
          </div>
        </section>
        <section id="features" className="border-b py-20">
          <div className="mx-auto grid max-w-6xl gap-12 px-4 md:grid-cols-[.8fr_1.2fr]">
            <div>
              <p className="text-sm font-semibold text-primary">{t("Cloud by design")}</p>
              <h2 className="mt-2 text-3xl font-semibold">
                {t("Close your laptop. Recording continues.")}
              </h2>
              <p className="mt-4 text-muted-foreground">
                {t(
                  "Monitoring and recording run in the cloud, not in your browser, so nothing on your side needs to stay on.",
                )}
              </p>
            </div>
            <div className="grid gap-px overflow-hidden rounded-lg border bg-border sm:grid-cols-2">
              {[
                "Automatic live detection",
                "Cloud recording",
                "Multiple monitored channels",
                "Recording library",
                "Browser playback",
                "Fast downloads",
                "Credit usage history",
                retentionFeature(publicPricing),
              ].map((x, i) => (
                <div key={x} className="flex items-center gap-3 bg-background p-4 text-sm">
                  <Check className="size-4 text-success" />
                  {t(x)}
                </div>
              ))}
            </div>
          </div>
        </section>
        <RecordingExamples />
        <section className="py-20">
          <div className="mx-auto max-w-5xl px-4 text-center">
            {isDemoMode ? (
              <>
                <h2 className="text-3xl font-semibold">{t("Simple plans, clear limits.")}</h2>
                <div className="mt-10 grid gap-5 text-left md:grid-cols-2">
                  {planList.map((plan) => (
                    <PlanCard
                      key={plan.id}
                      name={plan.name}
                      price={
                        plan.priceMonthlyUsd === 0
                          ? "Free"
                          : formatCurrencyUsd(plan.priceMonthlyUsd, language)
                      }
                      features={[...plan.features]}
                    />
                  ))}
                </div>
                <p className="mx-auto mt-5 max-w-2xl text-xs text-muted-foreground">
                  {t(planMediaFootnote)}
                </p>
              </>
            ) : (
              <>
                <h2 className="text-3xl font-semibold">{t("Pay as you go with credits.")}</h2>
                <p className="mx-auto mt-4 max-w-2xl text-sm leading-6 text-muted-foreground">
                  {t("Buy a credit package once and use it whenever your channels go live.")}
                </p>
                <div className="mt-10 grid gap-5 text-left md:grid-cols-3">
                  {(
                    [
                      [
                        "No subscription",
                        "One-time credit packages. Nothing renews automatically, and credits never expire.",
                      ],
                      [
                        "Pay for recording time",
                        "Credits are used only while a livestream is being recorded. Monitoring offline channels is free.",
                      ],
                      [
                        "Free trial",
                        "New accounts get free credits after verifying their email, so you can try a real recording first.",
                      ],
                    ] as const
                  ).map(([title, body]) => (
                    <section key={title} className="rounded-lg border bg-surface p-5">
                      <h3 className="font-medium">{t(title)}</h3>
                      <p className="mt-2 text-sm leading-6 text-muted-foreground">{t(body)}</p>
                    </section>
                  ))}
                </div>
                <Button className="mt-8" variant="outline" asChild>
                  <Link to={authenticated ? "/billing" : "/pricing"}>
                    {t(authenticated ? "Buy credits" : "See pricing")}
                  </Link>
                </Button>
              </>
            )}
          </div>
        </section>
      </main>
      <section id="faq" className="border-t py-20">
        <div className="mx-auto max-w-3xl px-4">
          <h2 className="text-3xl font-semibold">{t("Frequently asked questions")}</h2>
          <dl className="mt-8 divide-y border-y">
            {(isDemoMode
              ? [
                  [
                    "Do I need to keep my computer on?",
                    "In the production product, monitoring and recording are designed to run in backend services rather than in your browser.",
                  ],
                  [
                    "Which channels can I add?",
                    "Only TikTok channels you own, manage, or have permission to record. Douyin support is coming soon.",
                  ],
                  [
                    "How long are recordings kept?",
                    "Recordings are kept for your plan’s retention period — 3 days on Free, 30 days on Pro — then deleted automatically.",
                  ],
                  [
                    "What happens if I reach my quota?",
                    "Automatic recording pauses until your quota resets or you upgrade. Existing recordings stay available.",
                  ],
                ]
              : [
                  [
                    "Do I need to keep my computer on?",
                    "No. Monitoring and recording run in the cloud, so you can close your browser or turn off your computer.",
                  ],
                  [
                    "Which channels can I add?",
                    "Only TikTok channels you own, manage, or have explicit permission to record and archive.",
                  ],
                  [
                    "How does pricing work?",
                    "You buy credits once and they are used while livestreams are recorded. Credits never expire. See the pricing page for packages and the current rate.",
                  ],
                  [
                    "How long are recordings kept?",
                    `${retentionSentence(publicPricing)}. Watch them in the browser or download any recording you want to keep longer.`,
                  ],
                  [
                    "What happens if I run out of credits?",
                    "A recording continues until the livestream ends or your credits run out, and everything recorded up to that point is saved. Add credits from Billing to keep recording.",
                  ],
                ]
            ).map(([q, a]) => (
              <div key={q} className="py-5">
                <dt className="font-medium">{t(q ?? "")}</dt>
                <dd className="mt-2 text-sm leading-6 text-muted-foreground">{t(a ?? "")}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>
      <PublicFooter />
    </div>
  );
}

export function AuthPage({
  mode,
  token = "",
}: {
  mode: "sign-in" | "sign-up" | "forgot" | "reset";
  token?: string;
}) {
  const { t } = usePreferences();
  const navigate = useNavigate();
  const { signIn, signInWithSocial, completeSocialSignUp, status, user: authUser } = useAuth();
  // Shown when a Google/Apple sign-in would create a new account without consent.
  const [socialConsentOpen, setSocialConsentOpen] = useState(false);
  const [socialConsentChecked, setSocialConsentChecked] = useState(false);
  const [socialConsentError, setSocialConsentError] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [pw, setPw] = useState("");
  const [pw2, setPw2] = useState("");
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<{
    email?: string | undefined;
    password?: string | undefined;
    confirm?: string | undefined;
    agree?: string | undefined;
  }>({});
  // Sign-up requires confirming age (18+, TikTok's LIVE minimum) and the legal terms.
  const [agreed, setAgreed] = useState(false);
  const [linkExpired, setLinkExpired] = useState(false);
  const trialLabel = useTrialMinutesLabel();
  const agreementError =
    "Confirm that you are at least 18 and agree to the Terms of Use and Privacy Policy.";
  useEffect(() => {
    if (isDemoMode || (mode !== "sign-in" && mode !== "sign-up") || status !== "authenticated") {
      return;
    }
    void navigate({
      to: authUser && isAdminRole(authUser.role) ? "/admin/system" : "/overview",
      replace: true,
    });
  }, [authUser, mode, navigate, status]);

  const restoringExistingSession =
    !isDemoMode && (mode === "sign-in" || mode === "sign-up") && status !== "guest";

  const copy = {
    "sign-in": ["Welcome back", "Sign in to see your channels and recordings.", "Sign in"],
    "sign-up": ["Create your account", "No credit card required.", "Create account"],
    forgot: [
      "Reset your password",
      "Enter your email and we’ll send you a reset link.",
      "Send reset link",
    ],
    reset: ["Set a new password", "Use at least 8 characters.", "Update password"],
  }[mode];
  const startSocial = async (provider: SocialProvider) => {
    setErr(null);
    if (mode === "sign-up" && !agreed) {
      setFieldErrors((current) => ({ ...current, agree: agreementError }));
      return;
    }
    if (isDemoMode) {
      toast("Social sign-in isn't connected in this prototype.");
      return;
    }
    setBusy(true);
    try {
      // On sign-up the checkbox above already captured consent.
      const currentUser = await signInWithSocial(
        provider,
        mode === "sign-up" ? currentLegalConsent() : undefined,
      );
      await navigate({ to: isAdminRole(currentUser.role) ? "/admin/system" : "/overview" });
    } catch (error) {
      if (error instanceof ApiError && error.code === "LEGAL_CONSENT_REQUIRED") {
        setSocialConsentChecked(false);
        setSocialConsentError(null);
        setSocialConsentOpen(true);
        return;
      }
      setErr(
        error instanceof ApiError ? authErrorMessage(error) : socialProviderErrorMessage(error),
      );
    } finally {
      setBusy(false);
    }
  };
  const finishSocialSignUp = async () => {
    setSocialConsentError(null);
    setBusy(true);
    try {
      const currentUser = await completeSocialSignUp(currentLegalConsent());
      setSocialConsentOpen(false);
      await navigate({ to: isAdminRole(currentUser.role) ? "/admin/system" : "/overview" });
    } catch (error) {
      setSocialConsentError(
        error instanceof ApiError ? authErrorMessage(error) : socialProviderErrorMessage(error),
      );
    } finally {
      setBusy(false);
    }
  };
  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setErr(null);
    // Validate every field at once so each error shows next to its field.
    const nextErrors: typeof fieldErrors = {};
    if (mode !== "reset") {
      if (!email.trim()) nextErrors.email = "Email is required.";
      else if (!/^\S+@\S+\.\S+$/.test(email)) nextErrors.email = "Enter a valid email address.";
    }
    if (mode === "sign-in" && !pw) {
      nextErrors.password = "Password is required.";
    }
    if ((mode === "sign-up" || mode === "reset") && pw.length < 8) {
      nextErrors.password = pw
        ? "Password must be at least 8 characters."
        : "Password is required.";
    }
    if (mode === "reset" && pw !== pw2) {
      nextErrors.confirm = "Passwords don’t match.";
    }
    if (mode === "sign-up" && !agreed) {
      nextErrors.agree = agreementError;
    }
    setFieldErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) {
      return;
    }
    if (mode === "reset" && !token) {
      setLinkExpired(true);
      return;
    }

    setBusy(true);

    if (isDemoMode) {
      setTimeout(() => {
        setBusy(false);
        if (mode === "sign-in") void navigate({ to: "/admin/system" });
        else if (mode === "sign-up") void navigate({ to: "/verify-email", search: { token: "" } });
        else setDone(true);
      }, 700);
      return;
    }

    try {
      if (mode === "sign-in") {
        const currentUser = await signIn(email, pw);
        await navigate({ to: isAdminRole(currentUser.role) ? "/admin/system" : "/overview" });
      } else if (mode === "sign-up") {
        await authApi.register({
          email,
          password: pw,
          display_name: name.trim() || null,
          consent: currentLegalConsent(),
        });
        if (typeof window !== "undefined") {
          window.sessionStorage.setItem("savestream:pending-verification-email", email);
        }
        await navigate({ to: "/verify-email", search: { token: "" } });
      } else if (mode === "forgot") {
        await authApi.forgotPassword(email);
        setDone(true);
      } else {
        await authApi.resetPassword(token, pw);
        setDone(true);
      }
    } catch (error) {
      if (mode === "reset" && isExpiredLinkError(error)) {
        setLinkExpired(true);
        return;
      }
      setErr(authErrorMessage(error));
    } finally {
      setBusy(false);
    }
  };
  if (restoringExistingSession) {
    return (
      <RestoringSessionScreen
        message={
          status === "authenticated" ? "Returning to your workspace…" : "Restoring your session…"
        }
      />
    );
  }

  const errorAlert = err && (
    <p role="alert" className="flex items-start gap-2 text-sm text-destructive">
      <AlertCircle className="mt-0.5 size-4 shrink-0" />
      {err}
    </p>
  );
  const submitButton = (
    <Button className="w-full" size="lg" type="submit" disabled={busy}>
      {busy && (
        <span className="size-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
      )}
      {t(copy[2] ?? "")}
    </Button>
  );

  if (mode === "forgot") {
    return (
      <AuthCardLayout>
        {done ? (
          <div className="flex flex-col items-center gap-[18px] text-center">
            <IconTile tone="ok">
              <Send className="size-7" />
            </IconTile>
            <h1 className="text-[26px] font-extrabold tracking-[-0.02em]">
              {t("Check your email")}
            </h1>
            <p className="text-muted-foreground">
              {t("If an account exists for")} <b className="text-foreground">{email}</b>,{" "}
              {t("a reset link is on its way.")} It’s valid for {ONE_TIME_LINK_MINUTES} minutes.
            </p>
            <Button variant="outline" className="w-full" asChild>
              <Link to="/sign-in">{t("Back to sign in")}</Link>
            </Button>
            <span className="text-sm text-muted-foreground">
              {t("Nothing after 5 minutes?")}{" "}
              <button
                type="button"
                className="font-semibold text-accent-ink hover:underline"
                onClick={() => {
                  if (isDemoMode) {
                    toast.success("Reset link sent again");
                    return;
                  }
                  void authApi
                    .forgotPassword(email)
                    .then(() => toast.success("Reset link sent again"))
                    .catch((error) => toast.error(authErrorMessage(error)));
                }}
              >
                {t("Send again")}
              </button>
            </span>
            {isDemoMode && (
              <Link
                to="/reset-password"
                search={{ token: "" }}
                className="text-xs text-accent-ink underline underline-offset-4"
              >
                Prototype: open the reset link
              </Link>
            )}
          </div>
        ) : (
          <>
            <Link to="/sign-in" className="self-start text-sm font-semibold text-accent-ink">
              ← {t("Back to sign in")}
            </Link>
            <div className="flex flex-col gap-2">
              <h1 className="text-[30px] font-extrabold leading-tight tracking-[-0.03em]">
                {t("Forgot your password?")}
              </h1>
              <p className="text-muted-foreground">
                {t("Enter the email you signed up with and we’ll send a reset link.")}
              </p>
            </div>
            <form className="flex flex-col gap-4" onSubmit={submit} noValidate>
              <Field
                label="Email"
                placeholder="you@example.com"
                type="email"
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value);
                  if (fieldErrors.email) setFieldErrors((c) => ({ ...c, email: undefined }));
                }}
                autoComplete="email"
                error={fieldErrors.email}
              />
              {errorAlert}
              {submitButton}
            </form>
            <p className="text-xs text-muted-foreground">
              {t(
                "Signed up with Google or Apple? Use that button on the sign-in page instead — no password needed.",
              )}
            </p>
          </>
        )}
      </AuthCardLayout>
    );
  }

  if (mode === "reset") {
    return (
      <AuthCardLayout>
        {done ? (
          <div className="flex flex-col items-center gap-3.5 text-center">
            <IconTile tone="ok" size="md">
              <Check className="size-6" />
            </IconTile>
            <h1 className="text-2xl font-bold">{t("Password updated")}</h1>
            <p className="text-sm text-muted-foreground">
              {t(
                "Your password has been changed. Other sessions were signed out for your security.",
              )}
            </p>
            <Button asChild className="w-full">
              <Link to="/sign-in">{t("Sign in")}</Link>
            </Button>
          </div>
        ) : linkExpired ? (
          <div className="flex flex-col items-center gap-3.5 text-center">
            <IconTile tone="warn" size="md">
              <Clock3 className="size-6" />
            </IconTile>
            <h1 className="text-2xl font-bold">{t("This link has expired")}</h1>
            <p className="text-sm text-muted-foreground">
              Reset links work for {ONE_TIME_LINK_MINUTES} minutes and only once.
            </p>
            <Button variant="outline" asChild className="w-full">
              <Link to="/forgot-password">{t("Send a new link")}</Link>
            </Button>
          </div>
        ) : (
          <>
            <div className="flex flex-col gap-2">
              <h1 className="text-[30px] font-extrabold leading-tight tracking-[-0.03em]">
                {t("Set a new password")}
              </h1>
              <p className="text-muted-foreground">{t("Use at least 8 characters.")}</p>
            </div>
            <form className="flex flex-col gap-4" onSubmit={submit} noValidate>
              <div className="flex flex-col gap-2">
                <PasswordField
                  id="pw"
                  label="New password"
                  value={pw}
                  onChange={(value) => {
                    setPw(value);
                    if (fieldErrors.password)
                      setFieldErrors((c) => ({ ...c, password: undefined }));
                  }}
                  showStrength
                  error={fieldErrors.password}
                />
              </div>
              <PasswordField
                id="pw2"
                label="Confirm new password"
                value={pw2}
                onChange={(value) => {
                  setPw2(value);
                  if (fieldErrors.confirm) setFieldErrors((c) => ({ ...c, confirm: undefined }));
                }}
                error={fieldErrors.confirm}
              />
              {errorAlert}
              {submitButton}
            </form>
          </>
        )}
      </AuthCardLayout>
    );
  }

  const signUp = mode === "sign-up";
  const showSocial = isDemoMode || firebaseSocialConfigured;
  return (
    <AuthSplitLayout
      variant={signUp ? "sign-up" : "sign-in"}
      topRight={
        signUp ? (
          <span className="text-sm text-muted-foreground">
            {t("Have an account?")}{" "}
            <Link to="/sign-in" className="font-semibold text-accent-ink">
              {t("Sign in")}
            </Link>
          </span>
        ) : undefined
      }
    >
      <div className="flex flex-col gap-2">
        {signUp && trialLabel && (
          <span className="inline-flex h-7 items-center gap-1.5 self-start rounded-full bg-success-subtle px-3 text-xs font-bold text-success">
            <span className="size-1.5 rounded-full bg-current" />
            Includes {trialLabel}
          </span>
        )}
        <h1 className="text-[32px] font-extrabold leading-tight tracking-[-0.03em]">
          {t(copy[0] ?? "")}
        </h1>
        <p className="text-muted-foreground">{t(copy[1] ?? "")}</p>
      </div>
      {showSocial && (
        <>
          <div className={cn("flex gap-2.5", signUp ? "flex-row" : "flex-col")}>
            <SocialButton
              provider="google"
              label={signUp ? "Google" : t("Continue with Google")}
              disabled={busy}
              onClick={() => void startSocial("google")}
              className={signUp ? "flex-1" : undefined}
            />
            <SocialButton
              provider="apple"
              label={signUp ? "Apple" : t("Continue with Apple")}
              disabled={busy}
              onClick={() => void startSocial("apple")}
              className={signUp ? "flex-1" : undefined}
            />
          </div>
          <OrDivider />
        </>
      )}
      <form className="flex flex-col gap-4" onSubmit={submit} noValidate>
        {signUp && (
          <Field
            label="Your name"
            placeholder="Alex Nguyen"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoComplete="name"
          />
        )}
        <Field
          label="Email"
          placeholder="you@example.com"
          type="email"
          value={email}
          onChange={(e) => {
            setEmail(e.target.value);
            if (fieldErrors.email) setFieldErrors((c) => ({ ...c, email: undefined }));
          }}
          autoComplete="email"
          error={fieldErrors.email}
        />
        {signUp ? (
          <div className="flex flex-col gap-2">
            <PasswordField
              id="pw"
              label="Password"
              value={pw}
              onChange={(value) => {
                setPw(value);
                if (fieldErrors.password) setFieldErrors((c) => ({ ...c, password: undefined }));
              }}
              error={fieldErrors.password}
            />
            <PasswordChecklist value={pw} />
          </div>
        ) : (
          <div>
            <div className="flex items-center justify-between gap-3">
              <label htmlFor="password" className="text-sm font-medium">
                {t("Password")}
              </label>
              <Link to="/forgot-password" className="text-sm font-semibold text-accent-ink">
                {t("Forgot password?")}
              </Link>
            </div>
            <PasswordInput
              id="password"
              className="mt-2"
              value={pw}
              onChange={(e) => {
                setPw(e.target.value);
                if (fieldErrors.password) setFieldErrors((c) => ({ ...c, password: undefined }));
              }}
              placeholder="Password"
              autoComplete="current-password"
              aria-invalid={fieldErrors.password ? true : undefined}
              aria-describedby={fieldErrors.password ? "password-error" : undefined}
            />
            {fieldErrors.password && (
              <p id="password-error" className="mt-1.5 text-xs text-destructive">
                {t(fieldErrors.password)}
              </p>
            )}
          </div>
        )}
        {signUp && (
          <div>
            <label className="flex items-start gap-2.5 text-sm leading-5">
              <input
                type="checkbox"
                className={cn(
                  "mt-0.5 size-4 shrink-0 accent-primary",
                  fieldErrors.agree && "outline outline-1 outline-destructive",
                )}
                checked={agreed}
                required
                aria-invalid={fieldErrors.agree ? true : undefined}
                aria-describedby={fieldErrors.agree ? "agree-error" : undefined}
                onChange={(event) => {
                  setAgreed(event.target.checked);
                  if (event.target.checked) {
                    setFieldErrors((current) => ({ ...current, agree: undefined }));
                  }
                }}
              />
              <span>
                I am at least 18 and agree to the{" "}
                <Link
                  to="/terms"
                  className="font-semibold text-accent-ink underline-offset-4 hover:underline"
                >
                  Terms of Use
                </Link>{" "}
                and{" "}
                <Link
                  to="/privacy"
                  className="font-semibold text-accent-ink underline-offset-4 hover:underline"
                >
                  Privacy Policy
                </Link>
                .
              </span>
            </label>
            {fieldErrors.agree && (
              <p
                id="agree-error"
                className="mt-1.5 flex items-start gap-1.5 pl-[26px] text-xs text-destructive"
              >
                {fieldErrors.agree}
              </p>
            )}
          </div>
        )}
        {errorAlert}
        {submitButton}
      </form>
      <Dialog
        open={socialConsentOpen}
        onOpenChange={(open) => {
          if (!busy) setSocialConsentOpen(open);
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Create your SaveStream account</DialogTitle>
            <DialogDescription>
              This Google or Apple account is new to SaveStream. Confirm the following to finish
              creating your account.
            </DialogDescription>
          </DialogHeader>
          <label className="flex items-start gap-2 text-sm leading-5">
            <input
              type="checkbox"
              className="mt-0.5 size-4 shrink-0 accent-primary"
              checked={socialConsentChecked}
              onChange={(event) => setSocialConsentChecked(event.target.checked)}
            />
            <span>
              I am at least 18 and agree to the{" "}
              <Link to="/terms" target="_blank" className="underline underline-offset-4">
                Terms of Use
              </Link>{" "}
              and{" "}
              <Link to="/privacy" target="_blank" className="underline underline-offset-4">
                Privacy Policy
              </Link>
              .
            </span>
          </label>
          {socialConsentError && (
            <p role="alert" className="text-sm text-destructive">
              {socialConsentError}
            </p>
          )}
          <DialogFooter>
            <Button variant="outline" disabled={busy} onClick={() => setSocialConsentOpen(false)}>
              Cancel
            </Button>
            <Button
              disabled={busy || !socialConsentChecked}
              onClick={() => void finishSocialSignUp()}
            >
              Create account
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      {!signUp && (
        <p className="text-center text-sm text-muted-foreground">
          {t("New to SaveStream?")}{" "}
          <Link to="/sign-up" className="font-semibold text-accent-ink">
            {trialLabel ? `Create an account — ${trialLabel}` : t("Create account")}
          </Link>
        </p>
      )}
    </AuthSplitLayout>
  );
}
function Field({
  label,
  id,
  error,
  ...props
}: { label: string; error?: string | null | undefined } & ComponentProps<typeof Input>) {
  const { t } = usePreferences();
  const fid = id ?? label.toLowerCase().replace(/\s+/g, "-");
  return (
    <div>
      <label htmlFor={fid} className="block text-sm font-medium">
        {t(label)}
      </label>
      <Input
        id={fid}
        className={cn("mt-2", error && "border-destructive focus-visible:ring-destructive")}
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? `${fid}-error` : undefined}
        {...props}
      />
      {error && (
        <p id={`${fid}-error`} className="mt-1.5 text-xs text-destructive">
          {t(error)}
        </p>
      )}
    </div>
  );
}
const onboardingSteps = [
  { title: "Add a channel", detail: "Your TikTok username" },
  { title: "Recording", detail: "Auto-record & monitoring" },
  { title: "Notifications", detail: "How we reach you" },
  { title: "Done", detail: "Start recording" },
] as const;

export function OnboardingPage() {
  const navigate = useNavigate();
  const search = useSearch({ strict: false }) as { step?: number };
  const step = Math.min(4, Math.max(1, Number(search.step) || 1));
  const goTo = (next: number) => void navigate({ to: "/onboarding", search: { step: next } });
  const createChannel = useCreateChannelMutation();
  const updateChannel = useUpdateChannelMutation();
  const { query: entitlementQuery } = useEntitlementData(!isDemoMode);
  const { query: pricingQuery } = usePublicPricingData();
  const { query: channelsQuery } = useChannelsData();
  const preferencesQuery = useNotificationPreferencesData();
  const updatePreferences = useUpdateNotificationPreferencesMutation();
  const trialLabel = useTrialMinutesLabel();
  // Automatic recording needs purchased credits; the backend rejects it for Free.
  const canAutoRecord = isDemoMode || entitlementQuery.data?.plan === "pro";
  const [username, setUsername] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [channelId, setChannelId] = useState<string | null>(null);
  const [autoRecord, setAutoRecord] = useState(true);
  const [prefs, setPrefs] = useState({
    recording_started: true,
    recording_ready: true,
    recording_failed: true,
  });
  useEffect(() => {
    if (preferencesQuery.data) {
      setPrefs({
        recording_started: preferencesQuery.data.recording_started,
        recording_ready: preferencesQuery.data.recording_ready,
        recording_failed: preferencesQuery.data.recording_failed,
      });
    }
  }, [preferencesQuery.data]);
  const parsed = parseTikTokSource(username);
  const preview = useCreatorPreview(step === 1 && parsed ? parsed.source : null);
  const creator = preview.data?.creator ?? null;
  // Steps 2–4 refer to the channel added in step 1, or (after a reload)
  // the most recently added one.
  const channels = channelsQuery.data ?? [];
  const channel =
    channels.find((item) => item.id === channelId) ?? (step > 1 ? channels.at(-1) : undefined);
  const handle = channel?.handle ?? parsed?.handle ?? "your channel";
  const busy = createChannel.isPending || updateChannel.isPending || updatePreferences.isPending;

  const addChannel = async () => {
    if (!parsed || busy) return;
    setError(null);
    try {
      const watch = await createChannel.mutateAsync({
        source: parsed.source,
        auto_record: canAutoRecord,
      });
      setChannelId(watch.id);
      goTo(2);
    } catch (createError) {
      const duplicateId = existingWatchId(createError);
      if (duplicateId) {
        setChannelId(duplicateId);
        goTo(2);
        return;
      }
      setError(channelActionErrorMessage(createError));
    }
  };

  const saveRecording = async () => {
    if (channel && canAutoRecord && channel.autoRecord !== autoRecord) {
      try {
        await updateChannel.mutateAsync({ id: channel.id, input: { auto_record: autoRecord } });
      } catch (updateError) {
        setError(channelActionErrorMessage(updateError));
        return;
      }
    }
    setError(null);
    goTo(3);
  };

  const saveNotifications = async () => {
    try {
      await updatePreferences.mutateAsync(prefs);
    } catch {
      toast.error("Couldn’t save notification settings — you can change them later in Settings.");
    }
    goTo(4);
  };

  const next =
    step === 1
      ? {
          label: createChannel.isPending ? "Adding channel…" : "Add channel",
          run: addChannel,
          disabled: !parsed,
        }
      : step === 2
        ? { label: "Continue", run: saveRecording, disabled: false }
        : { label: "Finish setup", run: saveNotifications, disabled: false };

  return (
    <div className="relative flex min-h-screen flex-col bg-background">
      <header className="border-b bg-surface/80 backdrop-blur">
        <nav
          aria-label="Onboarding"
          className="mx-auto flex h-[68px] max-w-[1080px] items-center gap-4 px-4 sm:px-6"
        >
          <Logo homeTo="/overview" />
          <span className="text-sm text-muted-foreground">Step {step} of 4</span>
          <Button asChild variant="ghost" className="ml-auto">
            <Link to="/overview">Skip for now</Link>
          </Button>
        </nav>
      </header>
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-x-0 top-[68px] h-[420px] bg-[radial-gradient(700px_300px_at_50%_0%,color-mix(in_oklab,var(--color-primary)_14%,transparent),transparent_70%)]"
      />
      <main className="relative mx-auto flex w-full max-w-[1080px] flex-wrap items-start gap-8 px-4 py-10 sm:px-6 lg:gap-12 lg:py-14">
        <ol aria-label="Setup steps" className="flex w-full flex-col gap-1.5 lg:w-[260px]">
          {onboardingSteps.map((item, index) => {
            const number = index + 1;
            const done = number < step;
            const current = number === step;
            return (
              <li
                key={item.title}
                aria-current={current ? "step" : undefined}
                className={cn(
                  "flex items-center gap-3 rounded-[12px] px-3.5 py-3",
                  current && "bg-surface shadow-sm",
                )}
              >
                <span
                  className={cn(
                    "grid size-7 shrink-0 place-items-center rounded-full text-[13px] font-extrabold",
                    done
                      ? "bg-success text-white"
                      : current
                        ? "bg-primary text-primary-foreground"
                        : "bg-surface-2 text-muted-foreground",
                  )}
                >
                  {done ? <Check className="size-3.5" strokeWidth={3} /> : number}
                </span>
                <span>
                  <b className={cn("block text-sm", !(done || current) && "text-muted-foreground")}>
                    {item.title}
                  </b>
                  <span className="text-xs text-muted-foreground">{item.detail}</span>
                </span>
              </li>
            );
          })}
          {trialLabel && (
            <li className="mt-3.5 rounded-[14px] border bg-surface p-3.5">
              <span className="flex items-center gap-2 text-sm font-bold">
                <Gift className="size-4" />
                {trialLabel}
              </span>
              <span className="text-xs text-muted-foreground">
                Enough to test a real LIVE before you buy anything.
              </span>
            </li>
          )}
        </ol>
        <section className="flex min-w-0 flex-[1_1_520px] flex-col gap-6 rounded-[24px] border bg-surface p-6 shadow-sm sm:p-10">
          {step === 1 && (
            <>
              <div className="space-y-2">
                <h1 className="text-[30px] font-extrabold leading-tight tracking-tight">
                  Which TikTok channel should we watch?
                </h1>
                <p className="text-muted-foreground">
                  Add a channel you own or are authorized to record. You can add more later.
                </p>
              </div>
              <div className="space-y-1.5">
                <label htmlFor="onboarding-username" className="text-sm font-semibold">
                  TikTok username
                </label>
                <div className="relative">
                  <span className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 font-bold text-muted-foreground">
                    @
                  </span>
                  <Input
                    id="onboarding-username"
                    autoFocus
                    value={username}
                    onChange={(event) => {
                      setUsername(event.target.value);
                      setError(null);
                    }}
                    onKeyDown={(event) => {
                      if (event.key === "Enter") void addChannel();
                    }}
                    aria-invalid={Boolean(username) && !parsed}
                    placeholder="username or tiktok.com/@username"
                    className="h-[52px] pl-8 text-[17px]"
                  />
                </div>
                {username && !parsed && (
                  <p className="text-xs font-semibold text-destructive">
                    Enter a valid TikTok username or profile link.
                  </p>
                )}
              </div>
              {parsed && (
                <div className="flex items-center gap-3.5 rounded-[14px] border p-4">
                  <AvatarCircle
                    src={creator?.avatar_url}
                    initials={displayNameFromTikTokUsername(parsed.username)
                      .slice(0, 2)
                      .toUpperCase()}
                    size="lg"
                  />
                  <div className="min-w-0 flex-1">
                    <b className="block truncate">
                      {creator?.display_name || displayNameFromTikTokUsername(parsed.username)}
                    </b>
                    <span className="text-sm text-muted-foreground">{parsed.handle}</span>
                  </div>
                  {creator ? (
                    <span className="inline-flex h-6 items-center gap-1.5 rounded-full bg-success-subtle px-2.5 text-xs font-bold text-success">
                      <Check className="size-3" /> Found
                    </span>
                  ) : preview.isFetching ? (
                    <span className="text-xs text-muted-foreground">Looking up…</span>
                  ) : null}
                </div>
              )}
              <p className="flex items-start gap-2 rounded-[12px] bg-primary-subtle px-3 py-2.5 text-sm text-accent-ink">
                <ShieldCheck className="mt-0.5 size-4 shrink-0" />
                <span>
                  Only add channels you own, manage, or have permission to record (
                  <Link to="/acceptable-use" className="font-semibold hover:underline">
                    Acceptable Use Policy
                  </Link>
                  ).
                </span>
              </p>
            </>
          )}
          {step === 2 && (
            <>
              <div className="space-y-2">
                <h1 className="text-[30px] font-extrabold leading-tight tracking-tight">
                  How should we record {handle}?
                </h1>
                <p className="text-muted-foreground">
                  These are the defaults — change them anytime on the channel page.
                </p>
              </div>
              <div className="flex items-center gap-4 rounded-[14px] border p-4">
                <span className="flex-1">
                  <b className="block">Auto-record every LIVE</b>
                  <span className="text-sm text-muted-foreground">
                    {canAutoRecord
                      ? "Start recording as soon as the channel goes live."
                      : "Unlocks after you buy credits. Until then we detect LIVEs and notify you."}
                  </span>
                </span>
                <Switch
                  checked={canAutoRecord && autoRecord}
                  disabled={!canAutoRecord}
                  onCheckedChange={setAutoRecord}
                  aria-label="Auto-record every LIVE"
                />
              </div>
              <div className="flex items-center gap-4 rounded-[14px] border p-4">
                <span className="flex-1">
                  <b className="block">Monitoring</b>
                  <span className="text-sm text-muted-foreground">
                    We check the channel around the clock and start within about a minute of the
                    LIVE beginning.
                  </span>
                </span>
                <StatusBadge status="Waiting" />
              </div>
              <p className="flex items-start gap-2.5 rounded-[12px] border border-info/25 bg-info-subtle px-3.5 py-3 text-sm">
                <Clock3 className="mt-0.5 size-4 shrink-0 text-info" />
                <span>
                  Credits are charged per minute recorded. {retentionSentence(pricingQuery.data)} —
                  download anything you want to keep.
                </span>
              </p>
            </>
          )}
          {step === 3 && (
            <>
              <div className="space-y-2">
                <h1 className="text-[30px] font-extrabold leading-tight tracking-tight">
                  How should we tell you?
                </h1>
                <p className="text-muted-foreground">
                  We’ll notify you in SaveStream. You can fine-tune this in Settings →
                  Notifications.
                </p>
              </div>
              <div className="overflow-hidden rounded-[14px] border">
                {(
                  [
                    [
                      "recording_started",
                      "LIVE detected & recording started",
                      "So you know it’s working",
                    ],
                    ["recording_ready", "Recording ready", "With a link to watch or download"],
                    ["recording_failed", "Recording failed", "With the reason and what to do next"],
                  ] as const
                ).map(([key, title, detail]) => (
                  <div
                    key={key}
                    className="flex items-center gap-4 border-b px-4 py-3.5 last:border-b-0"
                  >
                    <span className="flex-1">
                      <b className="block text-sm">{title}</b>
                      <span className="text-xs text-muted-foreground">{detail}</span>
                    </span>
                    <Switch
                      checked={prefs[key]}
                      onCheckedChange={(value) =>
                        setPrefs((current) => ({ ...current, [key]: value }))
                      }
                      aria-label={title}
                    />
                  </div>
                ))}
              </div>
            </>
          )}
          {step === 4 && (
            <div className="flex flex-col items-center gap-4 py-4 text-center">
              <span className="grid size-[72px] place-items-center rounded-[22px] bg-success-subtle text-success">
                <Check className="size-8" strokeWidth={2.4} />
              </span>
              <h1 className="text-[30px] font-extrabold tracking-tight">You’re all set</h1>
              <p className="max-w-[420px] text-muted-foreground">
                We’re now watching <b className="text-foreground">{handle}</b>.{" "}
                {channel?.autoRecord && canAutoRecord
                  ? "The next time it goes LIVE, we’ll record it automatically and let you know."
                  : "We’ll let you know when it goes LIVE. Buy credits to record LIVEs automatically."}
              </p>
              <div className="flex flex-wrap justify-center gap-2.5">
                {channel ? (
                  <Button asChild size="lg">
                    <Link to="/channels/$id" params={{ id: channel.id }}>
                      Open channel
                    </Link>
                  </Button>
                ) : null}
                <Button asChild size="lg" variant="outline">
                  <Link to="/overview">Go to dashboard</Link>
                </Button>
              </div>
            </div>
          )}
          {error && (
            <p role="alert" className="text-sm font-medium text-destructive">
              {error}
            </p>
          )}
          {step < 4 && (
            <div className="flex items-center justify-between border-t pt-4">
              <Button variant="ghost" disabled={step === 1 || busy} onClick={() => goTo(step - 1)}>
                Back
              </Button>
              <Button size="lg" disabled={next.disabled || busy} onClick={() => void next.run()}>
                {next.label}
              </Button>
            </div>
          )}
        </section>
      </main>
    </div>
  );
}
export function OverviewPage() {
  return <ProductionOverviewPage />;
}

function greeting(now = new Date()) {
  const hour = now.getHours();
  return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening";
}

function recordingStartedAt(recording: RecordingModel): number {
  const time = new Date(`${recording.date} ${recording.time}`).getTime();
  return Number.isNaN(time) ? 0 : time;
}

const USAGE_RANGES = [7, 30, 90] as const;

function UsageChart({ recordings }: { recordings: RecordingModel[] }) {
  const [days, setDays] = useState<(typeof USAGE_RANGES)[number]>(30);
  const dayMs = 864e5;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const start = today.getTime() - (days - 1) * dayMs;
  const buckets = Array.from({ length: days }, () => 0);
  const previous = { from: start - days * dayMs, total: 0 };
  for (const recording of recordings) {
    const at = recordingStartedAt(recording);
    const hours = (recording.durationSeconds ?? 0) / 3600;
    if (at >= start) {
      const index = Math.min(days - 1, Math.floor((at - start) / dayMs));
      buckets[index] = (buckets[index] ?? 0) + hours;
    } else if (at >= previous.from) {
      previous.total += hours;
    }
  }
  const total = buckets.reduce((sum, value) => sum + value, 0);
  const peak = Math.max(...buckets, 0);
  const peakIndex = buckets.indexOf(peak);
  const change =
    previous.total > 0 ? Math.round(((total - previous.total) / previous.total) * 100) : null;
  const label = (offset: number) =>
    new Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(
      new Date(start + offset * dayMs),
    );
  return (
    <section
      aria-labelledby="usage-title"
      className="flex flex-col gap-3.5 rounded-[18px] border bg-surface p-5"
    >
      <div className="flex items-center justify-between gap-3">
        <h2 id="usage-title" className="text-[17px] font-bold">
          Recorded hours
        </h2>
        <div role="group" aria-label="Range" className="flex rounded-[10px] bg-surface-2 p-0.5">
          {USAGE_RANGES.map((range) => (
            <button
              key={range}
              type="button"
              aria-pressed={days === range}
              onClick={() => setDays(range)}
              className={cn(
                "h-7 rounded-[8px] px-2.5 text-xs font-bold text-muted-foreground",
                days === range && "bg-surface text-foreground shadow-sm",
              )}
            >
              {range} d
            </button>
          ))}
        </div>
      </div>
      <div className="flex items-baseline gap-2.5">
        <span className="font-mono text-[26px] font-semibold">{formatHoursLeft(total * 60)}</span>
        {change !== null && (
          <span
            className={cn(
              "text-xs font-bold",
              change >= 0 ? "text-success" : "text-muted-foreground",
            )}
          >
            {change >= 0 ? "+" : ""}
            {change}%
          </span>
        )}
        <span className="text-xs text-muted-foreground">
          {change !== null ? `vs previous ${days} days` : `last ${days} days`}
        </span>
      </div>
      <div
        role="img"
        aria-label={
          peak > 0
            ? `Daily recorded hours, last ${days} days, peak ${peak.toFixed(1)} hours on ${label(peakIndex)}`
            : `No recordings in the last ${days} days`
        }
        className="flex h-[120px] items-end gap-[3px]"
      >
        {buckets.map((value, index) => (
          <span
            key={index}
            title={value ? `${label(index)} · ${value.toFixed(1)} h` : `${label(index)} · no LIVE`}
            className={cn(
              "flex-1 rounded-t-[4px]",
              value === 0 ? "bg-surface-3" : index === peakIndex ? "bg-primary" : "bg-primary/45",
            )}
            style={{ height: `${value && peak ? Math.max(6, (value / peak) * 100) : 3}%` }}
          />
        ))}
      </div>
      <div className="flex justify-between text-xs text-muted-foreground">
        <span>{label(0)}</span>
        <span>{label(days - 1)}</span>
      </div>
    </section>
  );
}

function OverviewChecklist({
  emailVerified,
  hasChannel,
  hasRecording,
}: {
  emailVerified: boolean;
  hasChannel: boolean;
  hasRecording: boolean;
}) {
  const [handle, setHandle] = useState("");
  const [open, setOpen] = useState(false);
  const steps = [
    {
      title: "Verify your email",
      body: "Required before we can monitor channels and record.",
      done: emailVerified,
    },
    {
      title: "Add your first channel",
      body: "Enter the TikTok @username you want to auto-record. We’ll show a preview before you confirm.",
      done: hasChannel,
    },
    {
      title: "Record your first LIVE",
      body: "The next time your channel goes live, the recording appears in your library.",
      done: hasRecording,
    },
  ];
  const doneCount = steps.filter((step) => step.done).length;
  const firstOpen = steps.findIndex((step) => !step.done);
  return (
    <section
      aria-labelledby="checklist-title"
      className="overflow-hidden rounded-[20px] border bg-surface"
    >
      <div className="flex flex-wrap items-center gap-6 bg-gradient-to-br from-primary-subtle to-surface px-6 py-6 sm:px-8">
        <div className="min-w-0 flex-[1_1_320px] space-y-1.5">
          <p className="text-[11px] font-bold uppercase tracking-[.08em] text-accent-ink">
            Get started
          </p>
          <h2 id="checklist-title" className="text-2xl font-extrabold tracking-tight">
            Let’s get your first LIVE recorded.
          </h2>
          <p className="text-sm text-muted-foreground">
            Three quick steps. Once your channel is added we start watching it right away —
            monitoring is free.
          </p>
        </div>
        <div
          role="img"
          aria-label={`${doneCount} of 3 steps complete`}
          className="grid size-[92px] place-items-center rounded-full"
          style={{
            background: `conic-gradient(var(--color-primary) ${(doneCount / 3) * 360}deg, var(--color-border) 0)`,
          }}
        >
          <div className="grid size-[72px] place-items-center rounded-full bg-surface text-center">
            <span>
              <b className="block font-mono text-xl">{doneCount}/3</b>
              <span className="text-xs text-muted-foreground">done</span>
            </span>
          </div>
        </div>
      </div>
      <ol>
        {steps.map((step, index) => {
          const current = index === firstOpen;
          return (
            <li
              key={step.title}
              className={cn(
                "flex gap-4 border-t px-6 py-5 sm:px-8",
                current && "bg-primary-subtle/40",
              )}
            >
              <span
                className={cn(
                  "grid size-8 shrink-0 place-items-center rounded-full border-2 font-mono text-xs font-bold",
                  step.done
                    ? "border-success bg-success text-white"
                    : current
                      ? "border-primary text-accent-ink"
                      : "border-line-strong text-muted-foreground",
                )}
              >
                {step.done ? <Check className="size-4" strokeWidth={3} /> : index + 1}
              </span>
              <div className="min-w-0 flex-1 space-y-1">
                <div className="flex flex-wrap items-center gap-2">
                  <b className={cn(step.done && "text-muted-foreground line-through")}>
                    {step.title}
                  </b>
                  {step.done ? (
                    <span className="rounded-full bg-success-subtle px-2 py-0.5 text-xs font-bold text-success">
                      Complete
                    </span>
                  ) : current ? (
                    <span className="rounded-full bg-primary-subtle px-2 py-0.5 text-xs font-bold text-accent-ink">
                      Up next
                    </span>
                  ) : null}
                </div>
                <p className="text-sm text-muted-foreground">{step.body}</p>
                {index === 0 && !step.done && (
                  <Button asChild size="sm" className="mt-2">
                    <Link to="/verify-email" search={{ token: "" }}>
                      Verify email
                    </Link>
                  </Button>
                )}
                {index === 1 && !step.done && (
                  <form
                    className="mt-2.5 flex flex-wrap gap-2.5"
                    aria-label="Add your first channel"
                    onSubmit={(event) => {
                      event.preventDefault();
                      setOpen(true);
                    }}
                  >
                    <label className="relative min-w-[220px] flex-[1_1_280px]">
                      <span className="sr-only">TikTok username</span>
                      <span className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 font-bold text-muted-foreground">
                        @
                      </span>
                      <Input
                        value={handle}
                        onChange={(event) => setHandle(event.target.value)}
                        placeholder="your TikTok username"
                        className="h-11 pl-8"
                      />
                    </label>
                    <Button type="submit" className="h-11">
                      Add channel
                    </Button>
                  </form>
                )}
              </div>
            </li>
          );
        })}
      </ol>
      <AddChannelDialog initialInput={handle} open={open} onOpenChange={setOpen} />
    </section>
  );
}

function ProductionOverviewPage() {
  const { user } = useAuth();
  const { query: channelsQuery } = useChannelsData();
  const { query: recordingsQuery } = useRecordingsData();
  const { query: balanceQuery } = useCreditBalanceData();
  const { query: entitlementQuery } = useEntitlementData(!isDemoMode);
  const credits = useCreditSummary();

  if (channelsQuery.isPending || recordingsQuery.isPending || balanceQuery.isPending) {
    return (
      <AppShell>
        <PageHeader
          title="Overview"
          subtitle="Loading workspace status…"
          action={<AddChannelDialog />}
        />
        <div className="grid gap-5 md:grid-cols-[2fr_1fr_1fr]" aria-busy="true">
          {[0, 1, 2].map((i) => (
            <div key={i} className="h-40 animate-pulse rounded-[18px] border bg-surface-2" />
          ))}
        </div>
      </AppShell>
    );
  }

  if (
    channelsQuery.isError ||
    recordingsQuery.isError ||
    balanceQuery.isError ||
    !balanceQuery.data
  ) {
    return (
      <AppShell>
        <PageHeader title="Overview" action={<AddChannelDialog />} />
        <ErrorState
          title="Could not load workspace overview"
          body="SaveStream could not load part of your workspace. Please try again."
          onRetry={() => {
            void channelsQuery.refetch();
            void recordingsQuery.refetch();
            void balanceQuery.refetch();
          }}
        />
      </AppShell>
    );
  }

  const overviewChannels = channelsQuery.data ?? [];
  const overviewRecordings = [...(recordingsQuery.data ?? [])].sort(
    (a, b) => recordingStartedAt(b) - recordingStartedAt(a),
  );
  const balance = balanceQuery.data;
  const channelLimit = entitlementQuery.data?.limits.max_watches ?? null;
  const recordingChannels = overviewChannels.filter(
    (c) => c.backendStatus === "active" && c.status === "Recording",
  );
  const liveNotRecording = overviewChannels.filter(
    (c) => c.backendStatus === "active" && c.status === "Live",
  );
  const liveCount = recordingChannels.length + liveNotRecording.length;
  const monthStart = new Date();
  monthStart.setDate(1);
  monthStart.setHours(0, 0, 0, 0);
  const thisMonth = overviewRecordings.filter((r) => recordingStartedAt(r) >= monthStart.getTime());
  const monthSeconds = thisMonth.reduce((sum, r) => sum + (r.durationSeconds ?? 0), 0);
  const firstName = (user?.display_name ?? "").trim().split(/\s+/)[0];
  const showChecklist =
    !isDemoMode &&
    (!(user?.email_verified ?? true) ||
      overviewChannels.length === 0 ||
      overviewRecordings.length === 0);
  const activeRecording = recordingChannels[0]
    ? overviewRecordings.find((r) => r.id === recordingChannels[0]?.activeRecordingId)
    : undefined;
  const reservedMinutes =
    credits.minutes > 0 && balance.available > 0
      ? (balance.reserved / balance.available) * credits.minutes
      : balance.reserved;

  return (
    <AppShell>
      <div className="flex flex-col gap-6">
        <PageHeader
          title={firstName ? `${greeting()}, ${firstName}` : "Overview"}
          subtitle={
            liveCount === 0
              ? "Your channels, recordings, and credits at a glance."
              : `${pluralize(liveCount, "channel")} ${liveCount === 1 ? "is" : "are"} live: ${recordingChannels.length} recording${
                  liveNotRecording.length
                    ? `, ${liveNotRecording.length} ${liveNotRecording.length === 1 ? "needs" : "need"} your attention`
                    : ""
                }.`
          }
          action={
            <div className="flex flex-wrap gap-2">
              <Button asChild variant="outline">
                <Link to="/recordings">View recordings</Link>
              </Button>
              <AddChannelDialog />
            </div>
          }
        />

        {showChecklist && (
          <OverviewChecklist
            emailVerified={user?.email_verified ?? true}
            hasChannel={overviewChannels.length > 0}
            hasRecording={overviewRecordings.length > 0}
          />
        )}

        <div className="flex flex-wrap gap-5">
          <section
            aria-label="Credit balance"
            className="flex min-w-0 flex-[2_1_480px] flex-col gap-3 rounded-[18px] border bg-gradient-to-br from-surface to-surface-2 p-5"
          >
            <div className="flex items-center justify-between">
              <span className="text-sm font-bold text-muted-foreground">Credit balance</span>
              <Link to="/usage" className="text-sm font-bold text-accent-ink hover:underline">
                Usage history →
              </Link>
            </div>
            <div className="flex flex-wrap items-baseline gap-2.5">
              <span className="font-mono text-[44px] font-semibold leading-none tracking-tight">
                {credits.label}
              </span>
              <span className="text-muted-foreground">
                of recording left · {balance.available.toLocaleString("en")} credits available
              </span>
            </div>
            <div className="h-2.5 overflow-hidden rounded-full bg-surface-3">
              <span
                className={cn(
                  "block h-full rounded-full",
                  credits.state === "out"
                    ? "bg-destructive"
                    : credits.state === "low"
                      ? "bg-warning"
                      : "bg-gradient-to-r from-primary to-accent",
                )}
                style={{ width: `${credits.percent}%` }}
              />
            </div>
            <div className="flex flex-wrap items-center justify-between gap-3 text-sm">
              <span className="text-muted-foreground">
                {balance.reserved > 0
                  ? `${formatHoursLeft(reservedMinutes)} on hold for live recordings — released if unused.`
                  : "Credits are only used while a LIVE is being recorded."}
              </span>
              <Button asChild size="sm">
                <Link to="/billing">Buy credits</Link>
              </Button>
            </div>
          </section>
          <section
            aria-label="Channels monitored"
            className="flex flex-[1_1_220px] flex-col gap-2 rounded-[18px] border bg-surface p-5"
          >
            <span className="text-sm font-bold text-muted-foreground">Channels</span>
            <span className="font-mono text-[32px] font-semibold leading-tight">
              {overviewChannels.length}
              {channelLimit !== null && (
                <span className="text-lg text-muted-foreground"> / {channelLimit}</span>
              )}
            </span>
            {channelLimit !== null && (
              <div className="h-2 overflow-hidden rounded-full bg-surface-3">
                <span
                  className={cn(
                    "block h-full rounded-full",
                    overviewChannels.length >= channelLimit
                      ? "bg-warning"
                      : "bg-gradient-to-r from-primary to-accent",
                  )}
                  style={{
                    width: `${Math.min(100, (overviewChannels.length / Math.max(1, channelLimit)) * 100)}%`,
                  }}
                />
              </div>
            )}
            <span className="text-xs text-muted-foreground">
              {channelLimit !== null && overviewChannels.length >= channelLimit
                ? "Channel limit reached"
                : `${pluralize(overviewChannels.length, "channel")} added`}
            </span>
          </section>
          <section
            aria-label="Recordings this month"
            className="flex flex-[1_1_220px] flex-col gap-2 rounded-[18px] border bg-surface p-5"
          >
            <span className="text-sm font-bold text-muted-foreground">Recordings this month</span>
            <span className="font-mono text-[32px] font-semibold leading-tight">
              {thisMonth.length}
            </span>
            <span className="text-xs text-muted-foreground">
              {formatHoursLeft(monthSeconds / 60)} recorded
            </span>
          </section>
        </div>

        <div className="grid gap-5 [grid-template-columns:repeat(auto-fit,minmax(min(420px,100%),1fr))]">
          <section
            aria-labelledby="live-now"
            className="flex flex-col gap-4 rounded-[18px] border bg-surface p-5"
          >
            <div className="flex items-center justify-between">
              <h2 id="live-now" className="flex items-center gap-2 text-[17px] font-bold">
                <span
                  className={cn(
                    "size-2 rounded-full",
                    liveCount ? "animate-pulse bg-recording" : "bg-muted-foreground/40",
                  )}
                />
                Live now
              </h2>
              <span className="text-xs text-muted-foreground">Updates automatically</span>
            </div>
            {liveCount === 0 ? (
              <div className="flex flex-1 flex-col items-center justify-center gap-2 rounded-[14px] bg-surface-2 px-4 py-8 text-center">
                <Radio className="size-6 text-muted-foreground" />
                <b className="text-sm">No channels are live right now</b>
                <span className="text-xs text-muted-foreground">
                  {overviewChannels.length
                    ? "We’re watching your channels and will start recording when one goes live."
                    : "Add a channel and we’ll start watching it right away."}
                </span>
              </div>
            ) : (
              <>
                {recordingChannels.map((channel) => {
                  const recording =
                    channel.id === recordingChannels[0]?.id
                      ? activeRecording
                      : overviewRecordings.find((r) => r.id === channel.activeRecordingId);
                  return (
                    <div key={channel.id} className="flex flex-col gap-3">
                      <div className="flex items-center gap-3.5">
                        <div className="rounded-full ring-2 ring-recording ring-offset-2 ring-offset-surface">
                          <CreatorAvatar channel={channel} />
                        </div>
                        <div className="min-w-0 flex-1">
                          <b className="block truncate">{channel.handle}</b>
                          <span className="text-xs text-muted-foreground">
                            {recording ? `Started ${recording.time}` : "Recording on our servers"}
                          </span>
                        </div>
                        <StatusBadge status="Recording" pulse />
                      </div>
                      <div className="flex flex-wrap items-center gap-4 rounded-[14px] bg-surface-2 px-4 py-3.5">
                        <span className="font-mono text-[28px] font-semibold tracking-tight">
                          {recording?.duration ?? "—"}
                        </span>
                        <span className="ml-auto flex flex-col items-end">
                          <span className="text-xs text-muted-foreground">Recorded so far</span>
                          <b className="font-mono">{recording?.size ?? "—"}</b>
                        </span>
                      </div>
                      <div className="flex gap-2">
                        {channel.activeRecordingId && (
                          <Button asChild size="sm">
                            <Link to="/recordings/$id" params={{ id: channel.activeRecordingId }}>
                              View recording
                            </Link>
                          </Button>
                        )}
                        <Button asChild size="sm" variant="outline">
                          <Link to="/channels/$id" params={{ id: channel.id }}>
                            Channel details
                          </Link>
                        </Button>
                      </div>
                    </div>
                  );
                })}
                {liveNotRecording.map((channel) => (
                  <div
                    key={channel.id}
                    className="flex flex-wrap items-center gap-3 rounded-[14px] px-4 py-3.5 shadow-[inset_0_0_0_1.5px_color-mix(in_oklab,var(--color-recording)_45%,transparent)]"
                  >
                    <CreatorAvatar channel={channel} size="sm" />
                    <div className="min-w-0 flex-[1_1_200px]">
                      <div className="flex flex-wrap items-center gap-2">
                        <b className="text-sm">{channel.handle}</b>
                        <StatusBadge status="Live" />
                      </div>
                      <span className="text-xs text-muted-foreground">
                        {channel.liveReason ?? "Not recording."}
                      </span>
                    </div>
                    <Button asChild size="sm">
                      <Link to="/channels/$id" params={{ id: channel.id }}>
                        Details
                      </Link>
                    </Button>
                  </div>
                ))}
              </>
            )}
          </section>
          <UsageChart recordings={overviewRecordings} />
        </div>

        <section aria-labelledby="monitored" className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <h2 id="monitored" className="text-[17px] font-bold">
              Monitored channels
            </h2>
            <Link to="/channels" className="text-sm font-bold text-accent-ink hover:underline">
              All channels →
            </Link>
          </div>
          {overviewChannels.length ? (
            <>
              <div className="hidden overflow-x-auto rounded-[16px] border bg-surface md:block">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b bg-surface-2 text-left text-[11px] font-bold uppercase tracking-[.06em] text-muted-foreground">
                      <th scope="col" className="px-4 py-3">
                        Channel
                      </th>
                      <th scope="col" className="px-4 py-3">
                        Status
                      </th>
                      <th scope="col" className="px-4 py-3">
                        Last LIVE
                      </th>
                      <th scope="col" className="px-4 py-3">
                        Auto-record
                      </th>
                      <th scope="col" className="px-4 py-3 text-right">
                        Recordings
                      </th>
                      <th scope="col" className="px-4 py-3">
                        <span className="sr-only">Actions</span>
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {overviewChannels.map((channel) => {
                      const status: ChannelStatus =
                        channel.backendStatus === "active" ? channel.status : "Paused";
                      return (
                        <tr key={channel.id} className="border-b last:border-b-0">
                          <td className="px-4 py-3">
                            <Link
                              to="/channels/$id"
                              params={{ id: channel.id }}
                              className="flex items-center gap-3"
                            >
                              <CreatorAvatar channel={channel} size="sm" />
                              <span className="min-w-0">
                                <b className="block truncate">{channel.handle}</b>
                                <span className="text-xs text-muted-foreground">
                                  {channel.name}
                                </span>
                              </span>
                            </Link>
                          </td>
                          <td className="px-4 py-3">
                            <StatusBadge status={status} pulse={status === "Recording"} />
                            {status === "Live" && channel.liveReason && (
                              <span className="mt-1 block max-w-[260px] text-xs text-muted-foreground">
                                {channel.liveReason}
                              </span>
                            )}
                          </td>
                          <td className="px-4 py-3 text-muted-foreground">{channel.live}</td>
                          <td className="px-4 py-3">
                            <span
                              className={cn(
                                "rounded-full px-2 py-0.5 text-xs font-bold",
                                channel.autoRecord
                                  ? "bg-success-subtle text-success"
                                  : "bg-surface-2 text-muted-foreground",
                              )}
                            >
                              {channel.autoRecord ? "On" : "Off"}
                            </span>
                          </td>
                          <td className="px-4 py-3 text-right font-mono">{channel.recordings}</td>
                          <td className="px-4 py-3 text-right">
                            <Button
                              asChild
                              size="sm"
                              variant={status === "Live" ? "default" : "ghost"}
                            >
                              <Link to="/channels/$id" params={{ id: channel.id }}>
                                {status === "Live"
                                  ? "Details"
                                  : status === "Paused"
                                    ? "Resume"
                                    : "Open"}
                              </Link>
                            </Button>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
              <div className="grid grid-cols-[minmax(0,1fr)] gap-3 md:hidden">
                {overviewChannels.map((channel) => (
                  <ChannelGridCard key={channel.id} channel={channel} />
                ))}
              </div>
            </>
          ) : (
            <EmptyState
              icon={Radio}
              title="No channels yet"
              body="Add a TikTok channel you own or are authorized to record to start monitoring."
              action={<AddChannelDialog />}
            />
          )}
        </section>

        <section aria-labelledby="recent" className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <h2 id="recent" className="text-[17px] font-bold">
              Recent recordings
            </h2>
            <Link to="/recordings" className="text-sm font-bold text-accent-ink hover:underline">
              Library →
            </Link>
          </div>
          {overviewRecordings.length ? (
            <div className="grid gap-4 [grid-template-columns:repeat(auto-fill,minmax(min(170px,100%),1fr))]">
              {overviewRecordings.slice(0, 6).map((recording) => (
                <Link
                  key={recording.id}
                  to="/recordings/$id"
                  params={{ id: recording.id }}
                  aria-label={`${recording.handle}, ${recording.date}, ${recording.duration}`}
                  className={cn(
                    "relative flex aspect-[9/16] flex-col justify-between overflow-hidden rounded-[14px] p-2.5 text-white transition-transform hover:-translate-y-0.5",
                    recording.color,
                  )}
                >
                  <span
                    className="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-black/20"
                    aria-hidden="true"
                  />
                  <span className="relative flex items-start justify-between gap-2">
                    <StatusBadge status={recording.status} />
                    {recording.resolution !== "—" && (
                      <span className="rounded-md bg-black/40 px-1.5 py-0.5 font-mono text-[10px]">
                        {recording.resolution}
                      </span>
                    )}
                  </span>
                  <span className="relative">
                    <b className="block truncate text-sm">{recording.handle}</b>
                    <span className="font-mono text-xs opacity-85">
                      {recording.date.replace(/, \d{4}$/, "")} · {recording.duration}
                    </span>
                  </span>
                </Link>
              ))}
            </div>
          ) : (
            <EmptyState
              icon={FileVideo}
              title="No recordings yet"
              body="Completed and in-progress recordings will appear here."
            />
          )}
        </section>
      </div>
    </AppShell>
  );
}

export function SectionTitle({ title, action }: { title: string; action?: ReactNode }) {
  const { t } = usePreferences();
  return (
    <div className="mb-3 flex items-center justify-between">
      <h2 className="text-sm font-semibold">{t(title)}</h2>
      {action && <span className="text-xs font-medium text-primary">{action}</span>}
    </div>
  );
}

const channelFilters = [
  { id: "All", label: "All", dot: null },
  { id: "Recording", label: "Recording", dot: "bg-recording" },
  { id: "Live", label: "LIVE · not recording", dot: "bg-recording" },
  { id: "Waiting", label: "Waiting", dot: "bg-info" },
  { id: "Offline", label: "Offline", dot: "bg-muted-foreground/50" },
  { id: "Paused", label: "Paused", dot: "bg-warning" },
  { id: "Error", label: "Error", dot: "bg-destructive" },
] as const;

function ChannelsEmptyHero({
  trialLabel,
  channelLimit,
}: {
  trialLabel: string | null;
  channelLimit: number | null;
}) {
  const [value, setValue] = useState("");
  const [open, setOpen] = useState(false);
  return (
    <section className="relative overflow-hidden rounded-[20px] border bg-surface px-6 py-16 text-center">
      <div
        aria-hidden="true"
        className="absolute inset-0 bg-[radial-gradient(500px_260px_at_50%_0%,color-mix(in_oklab,var(--color-primary)_10%,transparent),transparent_70%)]"
      />
      <div className="relative mx-auto flex max-w-[520px] flex-col items-center gap-4">
        <span className="grid size-24 place-items-center rounded-[28px] bg-primary-subtle text-accent-ink">
          <Radio className="size-11" strokeWidth={1.6} />
        </span>
        <h2 className="text-[26px] font-extrabold tracking-tight">No channels yet</h2>
        <p className="max-w-[440px] text-muted-foreground">
          Add a TikTok @username. We’ll detect the next LIVE in about a minute and record it to the
          cloud — nothing to keep open.
        </p>
        <form
          className="mt-2 flex w-full flex-wrap justify-center gap-2.5"
          aria-label="Add a channel"
          onSubmit={(event) => {
            event.preventDefault();
            setOpen(true);
          }}
        >
          <label className="relative min-w-[240px] flex-1">
            <span className="sr-only">TikTok username</span>
            <span className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 font-bold text-muted-foreground">
              @
            </span>
            <Input
              value={value}
              onChange={(event) => setValue(event.target.value)}
              placeholder="TikTok username"
              className="h-12 pl-8"
            />
          </label>
          <Button type="submit" className="h-12">
            <Plus />
            Add channel
          </Button>
        </form>
        <div className="mt-2 flex flex-wrap justify-center gap-x-5 gap-y-2 text-sm text-muted-foreground">
          <span className="flex items-center gap-2">
            <span className="size-2 rounded-full bg-success" />
            Monitoring is free
          </span>
          {channelLimit !== null && (
            <span className="flex items-center gap-2">
              <span className="size-2 rounded-full bg-success" />
              Up to {pluralize(channelLimit, "channel")}
            </span>
          )}
          {trialLabel && (
            <span className="flex items-center gap-2">
              <span className="size-2 rounded-full bg-success" />
              {trialLabel}
            </span>
          )}
        </div>
      </div>
      <AddChannelDialog initialInput={value} open={open} onOpenChange={setOpen} />
    </section>
  );
}

export function ChannelsPage() {
  const { query: channelsQuery, state: channelsState } = useChannelsData();
  const { query: entitlementQuery } = useEntitlementData(!isDemoMode);
  const channelItems = channelsQuery.data ?? [];
  const entitlement = entitlementQuery.data;
  const { query: publicPricingQuery } = usePublicPricingData();
  const channelLimit =
    entitlement?.limits.max_watches ??
    publicPricingQuery.data?.free_max_channels_per_user ??
    (isDemoMode ? 3 : null);
  const channelCount = entitlement?.watch_count ?? channelItems.length;
  const trialMinutesLabel = useTrialMinutesLabel();
  const [q, setQ] = useState("");
  const [filter, setFilter] = useState<(typeof channelFilters)[number]["id"]>("All");
  const statusOf = (c: ChannelModel) => (c.backendStatus === "active" ? c.status : "Paused");
  const filtered = channelItems.filter(
    (c) =>
      (filter === "All" || statusOf(c) === filter) &&
      (c.name + c.handle).toLowerCase().includes(q.toLowerCase()),
  );
  const empty =
    channelsState.kind !== "loading" && channelsState.kind !== "error" && channelItems.length === 0;
  return (
    <AppShell>
      <PageHeader
        title="Channels"
        subtitle={
          empty
            ? "Add a TikTok channel and we’ll start watching it right away."
            : entitlement?.plan === "free"
              ? `We check monitored channels around the clock. ${freeWebSentence(publicPricingQuery.data, channelLimit)} Automatic recording unlocks after you buy credits.`
              : "We check monitored channels around the clock. Monitoring is free — only recording uses credits."
        }
        action={
          <div className="flex flex-wrap items-center gap-4">
            {channelLimit !== null && (
              <ChannelLimitMeter used={channelCount} limit={channelLimit} className="w-[200px]" />
            )}
            {!empty && <AddChannelDialog />}
          </div>
        }
      />
      {channelsState.kind === "loading" ? (
        <div
          className="grid gap-4 [grid-template-columns:repeat(auto-fill,minmax(min(320px,100%),1fr))]"
          aria-busy="true"
        >
          {[0, 1, 2].map((i) => (
            <div key={i} className="h-[230px] animate-pulse rounded-[18px] border bg-surface-2" />
          ))}
        </div>
      ) : channelsState.kind === "error" ? (
        <ErrorState
          title="Could not load channels"
          body="Something went wrong while loading your channels. Please try again."
          onRetry={() => channelsQuery.refetch()}
        />
      ) : empty ? (
        <>
          <ChannelsEmptyHero
            channelLimit={channelLimit}
            trialLabel={trialMinutesLabel ? `${trialMinutesLabel} ready` : null}
          />
          <p className="mt-5 text-center text-sm text-muted-foreground">
            Only add channels you own, manage, or have permission to record.{" "}
            <Link to="/acceptable-use" className="font-semibold text-accent-ink hover:underline">
              Acceptable Use Policy
            </Link>
          </p>
        </>
      ) : (
        <div className="flex flex-col gap-5">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div role="group" aria-label="Filter by status" className="flex flex-wrap gap-2">
              {channelFilters.map((f) => {
                const count =
                  f.id === "All"
                    ? channelItems.length
                    : channelItems.filter((c) => statusOf(c) === f.id).length;
                const active = filter === f.id;
                return (
                  <button
                    key={f.id}
                    type="button"
                    aria-pressed={active}
                    onClick={() => setFilter(f.id)}
                    className={cn(
                      "inline-flex h-9 items-center gap-2 rounded-full border px-3.5 text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-ring/25",
                      active
                        ? "border-primary bg-primary-subtle text-accent-ink"
                        : "bg-surface text-muted-foreground hover:text-foreground",
                    )}
                  >
                    {f.dot && (
                      <span aria-hidden="true" className={cn("size-2 rounded-full", f.dot)} />
                    )}
                    {f.label}
                    <span className="font-mono text-xs opacity-70">{count}</span>
                  </button>
                );
              })}
            </div>
            <div className="w-full sm:w-[260px]">
              <SearchInput value={q} onChange={setQ} placeholder="Search channels" />
            </div>
          </div>
          {filtered.length ? (
            <div className="grid gap-4 [grid-template-columns:repeat(auto-fill,minmax(min(320px,100%),1fr))]">
              {filtered.map((c) => (
                <ChannelGridCard key={c.id} channel={c} />
              ))}
            </div>
          ) : (
            <EmptyState
              icon={Search}
              title="No channels match"
              body={`None of your ${pluralize(channelItems.length, "channel")} match this ${q ? "search" : "filter"} right now.`}
              action={
                <Button
                  variant="outline"
                  onClick={() => {
                    setQ("");
                    setFilter("All");
                  }}
                >
                  Show all channels
                </Button>
              }
            />
          )}
          <p className="flex flex-wrap items-center gap-2.5 rounded-[14px] border border-primary/20 bg-primary-subtle px-4 py-3 text-sm text-accent-ink">
            <ShieldCheck className="size-[18px] shrink-0" />
            <span className="flex-1">
              Only add channels you own, manage, or have permission to record.
            </span>
            <Link to="/acceptable-use" className="font-bold hover:underline">
              Acceptable Use Policy
            </Link>
          </p>
        </div>
      )}
    </AppShell>
  );
}
export function ChannelDetailPage() {
  const { id } = useParams({ strict: false }) as { id?: string };
  const { query: channelQuery, state: channelState } = useChannelData(id);
  const { query: recordingsQuery } = useRecordingsData();

  if (channelState.kind === "loading") {
    return (
      <AppShell>
        <PageHeader title="Channel" subtitle="Loading channel…" />
        <div className="h-40 animate-pulse rounded-lg border bg-muted" aria-busy="true" />
      </AppShell>
    );
  }

  if (channelState.kind === "error") {
    return (
      <AppShell>
        <PageHeader title="Channel" />
        <ErrorState
          title="Could not load channel"
          body="SaveStream could not load this monitored channel."
          onRetry={() => channelQuery.refetch()}
        />
      </AppShell>
    );
  }

  const channel = channelQuery.data;
  if (!channel) {
    return (
      <AppShell>
        <PageHeader title="Channel not found" />
        <EmptyState
          icon={Radio}
          title="This channel doesn’t exist"
          body="It may have been removed from your account."
          action={
            <Button asChild variant="outline">
              <Link to="/channels">Back to channels</Link>
            </Button>
          }
        />
      </AppShell>
    );
  }

  const history = (recordingsQuery.data ?? []).filter(
    (recording) => recording.channelId === channel.id,
  );

  return (
    <ChannelDetail
      key={channel.id}
      channel={channel}
      history={history}
      onRefresh={() => channelQuery.refetch()}
    />
  );
}
export function RecordingsPage() {
  const { t } = usePreferences();
  const { query: recordingsQuery, state: recordingsState } = useRecordingsData();
  const { query: channelsQuery } = useChannelsData();
  const recordingItems = recordingsQuery.data ?? [];
  const channelItems = channelsQuery.data ?? [];
  const [mock, setMock] = useState<(typeof libraryStates)[number]["value"]>("populated");
  const viewState =
    recordingsState.kind === "loading"
      ? "loading"
      : recordingsState.kind === "error"
        ? "error"
        : recordingsState.kind === "empty"
          ? "empty"
          : isDemoMode
            ? mock
            : "populated";
  const [q, setQ] = useState("");
  const [view, setView] = useState<"list" | "grid">("list");
  const [status, setStatus] = useState("all");
  const [streamer, setStreamer] = useState("all");
  const [range, setRange] = useState("all");
  const [sort, setSort] = useState<"newest" | "oldest">("newest");
  const today = isDemoMode ? new Date("Sep 27, 2026").getTime() : Date.now();
  const list = recordingItems
    .filter(
      (r) =>
        (status === "all" || r.status === status) &&
        (streamer === "all" || r.channelId === streamer) &&
        (range === "all" || today - new Date(r.date).getTime() <= Number(range) * 864e5) &&
        (r.title + r.handle).toLowerCase().includes(q.toLowerCase()),
    )
    .sort((a, b) => {
      const d =
        new Date(`${a.date} ${a.time}`).getTime() - new Date(`${b.date} ${b.time}`).getTime();
      return sort === "newest" ? -d : d;
    });
  const filtered = status !== "all" || streamer !== "all" || range !== "all";
  const clear = () => {
    setQ("");
    setStatus("all");
    setStreamer("all");
    setRange("all");
  };
  const expiring = recordingItems.filter(
    (r) => r.status === "Ready" && r.expiresDays !== null && r.expiresDays <= 3,
  );
  return (
    <AppShell>
      <PageHeader
        title="Recordings"
        subtitle="Watch and download your completed livestream recordings."
      />
      {isDemoMode && <PrototypeStateBar value={mock} options={libraryStates} onChange={setMock} />}
      {viewState === "empty" ? (
        <EmptyState
          title="No recordings yet"
          body="Once one of your monitored channels goes live, the recording will automatically appear here."
          action={
            <div className="flex flex-col justify-center gap-2 sm:flex-row">
              <Button variant="outline" asChild>
                <Link to="/channels">{t("View channels")}</Link>
              </Button>
              <AddChannelDialog />
            </div>
          }
        />
      ) : (
        <>
          {viewState === "error" && (
            <div className="mb-4">
              <ErrorState
                title="We’re having trouble loading your library"
                body="Showing recordings from 2 minutes ago. We’re retrying automatically — your recordings are safe."
                onRetry={() => {
                  void recordingsQuery.refetch();
                  setMock("populated");
                }}
              />
            </div>
          )}
          {viewState === "populated" && expiring.length > 0 && (
            <div className="mb-4">
              <StateBanner
                tone="warning"
                icon={Clock3}
                title={`${pluralize(expiring.length, "recording")} ${expiring.length === 1 ? "expires" : "expire"} soon`}
                body="Recordings are removed automatically when your plan’s retention period ends. Download any you want to keep."
              />
            </div>
          )}
          <FilterBar>
            <div className="flex-1">
              <SearchInput value={q} onChange={setQ} placeholder="Search recordings" />
            </div>
            <div className="grid grid-cols-2 gap-2 sm:flex">
              <Select value={streamer} onValueChange={setStreamer}>
                <SelectTrigger className="sm:w-36" aria-label="Streamer">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">{t("All streamers")}</SelectItem>
                  {channelItems.map((c) => (
                    <SelectItem key={c.id} value={c.id}>
                      {c.handle}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Select value={status} onValueChange={setStatus}>
                <SelectTrigger className="sm:w-32" aria-label="Status">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">{t("All statuses")}</SelectItem>
                  <SelectItem value="Ready">{t("Ready")}</SelectItem>
                  <SelectItem value="Processing">{t("Processing")}</SelectItem>
                  <SelectItem value="Error">{t("Failed")}</SelectItem>
                </SelectContent>
              </Select>
              <Select value={range} onValueChange={setRange}>
                <SelectTrigger className="sm:w-36" aria-label="Date range">
                  <Calendar className="size-4" />
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">{t("All time")}</SelectItem>
                  <SelectItem value="7">{t("Last 7 days")}</SelectItem>
                  <SelectItem value="30">{t("Last 30 days")}</SelectItem>
                </SelectContent>
              </Select>
              <Button
                variant="outline"
                onClick={() => setSort((s) => (s === "newest" ? "oldest" : "newest"))}
              >
                <ArrowUpDown />
                {t(sort === "newest" ? "Newest first" : "Oldest first")}
              </Button>
            </div>
            <div className="hidden rounded-md border sm:flex">
              <Button
                size="icon"
                variant={view === "list" ? "secondary" : "ghost"}
                onClick={() => setView("list")}
                aria-label={t("List view")}
                aria-pressed={view === "list"}
              >
                <List />
              </Button>
              <Button
                size="icon"
                variant={view === "grid" ? "secondary" : "ghost"}
                onClick={() => setView("grid")}
                aria-label={t("Grid view")}
                aria-pressed={view === "grid"}
              >
                <Grid2X2 />
              </Button>
            </div>
          </FilterBar>
          {viewState === "loading" ? (
            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
              {[0, 1, 2, 3, 4, 5].map((i) => (
                <div key={i} className="animate-pulse overflow-hidden rounded-lg border">
                  <div className="aspect-video bg-muted" />
                  <div className="space-y-2 p-4">
                    <div className="h-3 w-2/3 rounded bg-muted" />
                    <div className="h-3 w-1/3 rounded bg-muted" />
                  </div>
                </div>
              ))}
            </div>
          ) : list.length === 0 ? (
            q ? (
              <EmptyState
                icon={Search}
                title={`No results for “${q}”`}
                body="Check the spelling or search by @handle or date."
                action={
                  <Button variant="outline" onClick={() => setQ("")}>
                    {t("Clear search")}
                  </Button>
                }
              />
            ) : (
              <EmptyState
                icon={Filter}
                title="No recordings match these filters"
                body={
                  filtered ? "Try a different streamer, status, or date range." : "Nothing to show."
                }
                action={
                  <Button variant="outline" onClick={clear}>
                    {t("Clear filters")}
                  </Button>
                }
              />
            )
          ) : view === "list" ? (
            <>
              <div className="hidden overflow-hidden rounded-lg border bg-surface lg:block">
                <RecordingHeader />
                {list.map((r) => (
                  <RecordingRow key={r.id} recording={r} />
                ))}
              </div>
              <div className="grid gap-4 sm:grid-cols-2 lg:hidden">
                {list.map((r) => (
                  <RecordingCard key={r.id} recording={r} />
                ))}
              </div>
            </>
          ) : (
            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
              {list.map((r) => (
                <RecordingCard key={r.id} recording={r} />
              ))}
            </div>
          )}
        </>
      )}
    </AppShell>
  );
}
const processingBackendStatuses = new Set([
  "queued",
  "resolving",
  "waiting_live",
  "waiting_for_cloud_slot",
  "processing",
  "uploading",
]);

function recordingDetailState(recording: RecordingModel) {
  if (recording.backendStatus === "recording" || recording.backendStatus === "stop_requested") {
    return "active" as const;
  }
  if (processingBackendStatuses.has(recording.backendStatus)) return "processing" as const;
  if (recording.backendStatus === "completed") return "ready" as const;
  return "failed" as const;
}

function recordingMatchesForcedState(
  recording: RecordingModel,
  forced: "ready" | "active" | "processing" | "failed",
) {
  const state = recordingDetailState(recording);
  return state === forced;
}

function RecordingRealtimeNotice({
  state,
  lastEventAt,
}: {
  state: RecordingRealtimeState;
  lastEventAt: number | null;
}) {
  if (state === "idle" || state === "ended") return null;
  if (state === "fallback" || state === "reconnecting") {
    return (
      <div className="mb-4">
        <StateBanner
          tone="warning"
          icon={Wifi}
          title="Realtime updates are reconnecting"
          body="Live updates are reconnecting. Recording status still refreshes every few seconds."
        />
      </div>
    );
  }
  return (
    <div className="mb-4 flex items-center gap-2 text-xs text-muted-foreground">
      <span className="size-2 animate-pulse rounded-full bg-success" />
      {state === "connected" ? "Live recording updates connected" : "Connecting live updates…"}
      {lastEventAt ? ` · last event ${new Date(lastEventAt).toLocaleTimeString()}` : ""}
    </div>
  );
}

export function RecordingDetailPage({
  state: forced,
}: {
  state?: "ready" | "active" | "processing" | "failed";
}) {
  const { id } = useParams({ strict: false }) as { id?: string };
  const navigate = useNavigate();
  const { t } = usePreferences();
  const { query: recordingQuery, state: recordingState } = useRecordingData(id);
  const { query: recordingsQuery, state: recordingsState } = useRecordingsData();
  const { query: channelsQuery } = useChannelsData();
  const stopRecording = useStopRecordingMutation();
  const deleteRecording = useDeleteRecordingMutation();
  const downloadRecording = useRecordingDownload();
  const playbackLink = useRecordingDownloadMutation();
  const [quota, setQuota] = useState<"normal" | "low">("normal");
  const [upgrade, setUpgrade] = useState(false);
  const [del, setDel] = useState(false);

  const rec = forced
    ? (recordingsQuery.data ?? []).find((item) => recordingMatchesForcedState(item, forced))
    : recordingQuery.data;
  const sourceState = forced ? recordingsState : recordingState;
  const realtime = useRecordingRealtime(rec?.id, rec?.backendStatus);
  const artifactState = rec ? (forced ?? recordingDetailState(rec)) : (forced ?? null);
  const shouldLoadArtifacts = artifactState === "ready" || artifactState === "failed";
  const { query: artifactsQuery, state: artifactsState } = useRecordingArtifactsData(
    rec?.id,
    shouldLoadArtifacts,
  );

  if (sourceState.kind === "loading") {
    return (
      <AppShell>
        <PageHeader title="Recording" subtitle="Loading recording status…" />
        <div className="h-56 animate-pulse rounded-lg border bg-muted" aria-busy="true" />
      </AppShell>
    );
  }

  if (sourceState.kind === "error") {
    return (
      <AppShell>
        <PageHeader title="Recording" />
        <ErrorState
          title="Could not load recording"
          body="SaveStream could not load the current recording state."
          onRetry={() => {
            if (forced) void recordingsQuery.refetch();
            else void recordingQuery.refetch();
          }}
        />
      </AppShell>
    );
  }

  if (!rec)
    return (
      <AppShell>
        <PageHeader title="Recording not found" />
        <EmptyState
          title={
            forced === "active"
              ? "No active recording"
              : forced === "processing"
                ? "No recording is processing"
                : forced === "failed"
                  ? "No failed recording"
                  : "This recording isn’t available"
          }
          body={
            forced
              ? "There is no recording in this state right now."
              : "It may have been deleted or removed after its retention period ended."
          }
          action={
            <Button asChild variant="outline">
              <Link to="/recordings">Back to recordings</Link>
            </Button>
          }
        />
      </AppShell>
    );

  const state = forced ?? recordingDetailState(rec);
  const channelItems = channelsQuery.data ?? [];
  const channel = channelItems.find(
    (candidate) =>
      candidate.id === rec.channelId || candidate.handle.toLowerCase() === rec.handle.toLowerCase(),
  );
  const expiringSoon = state === "ready" && rec.expiresDays !== null && rec.expiresDays <= 3;
  const artifact = artifactsQuery.data?.find(
    (item) => item.kind === "video" && item.container === "mp4",
  );
  const download = () => {
    if (isDemoMode) {
      if (quota === "low") setUpgrade(true);
      else
        toast.success("Download started", {
          description: `${rec.size} · ${rec.handle} — ${rec.title}`,
        });
      return;
    }

    void downloadRecording.start(rec, { onError: () => void artifactsQuery.refetch() });
  };
  const actions =
    state === "active" ? (
      <Button
        variant="outline"
        disabled={!rec.actions.can_stop || stopRecording.isPending}
        onClick={() => {
          void stopRecording
            .mutateAsync(rec.id)
            .then(() => toast.success("Stop requested", { description: rec.handle }))
            .catch((error) =>
              toast.error("Could not stop recording", {
                description: recordingActionErrorMessage(error),
              }),
            );
        }}
      >
        <Pause />
        {stopRecording.isPending ? "Stopping…" : "Stop recording"}
      </Button>
    ) : state === "ready" ? (
      <div className="flex gap-2">
        <Button
          onClick={download}
          disabled={
            downloadRecording.isPreparing ||
            (!isDemoMode && (artifactsState.kind === "loading" || !artifact))
          }
        >
          <Download />
          {downloadRecording.isPreparing ? "Preparing…" : "Download video"}
        </Button>
        <Button
          variant="outline"
          disabled={!rec.actions.can_delete || deleteRecording.isPending}
          onClick={() => setDel(true)}
        >
          <Trash2 />
          Delete
        </Button>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="outline" size="icon" aria-label="More actions">
              <MoreHorizontal />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem
              onSelect={() => {
                void navigator.clipboard?.writeText(window.location.href);
                toast.success("Link copied");
              }}
            >
              Copy link
            </DropdownMenuItem>
            {channel && (
              <DropdownMenuItem
                onSelect={() => navigate({ to: "/channels/$id", params: { id: channel.id } })}
              >
                View channel
              </DropdownMenuItem>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    ) : state === "failed" ? (
      <div className="flex flex-wrap gap-2">
        {(isDemoMode || artifact) && (
          <Button variant="outline" disabled={downloadRecording.isPreparing} onClick={download}>
            <Download />
            {downloadRecording.isPreparing ? "Preparing…" : "Download partial"}
          </Button>
        )}
        {rec.actions.can_delete && (
          <Button
            variant="outline"
            disabled={deleteRecording.isPending}
            onClick={() => setDel(true)}
          >
            <Trash2 />
            Delete partial file
          </Button>
        )}
      </div>
    ) : state === "processing" ? (
      <Button disabled>
        <Download />
        Download available after processing
      </Button>
    ) : null;

  return (
    <AppShell>
      {channel && (
        <Link
          to="/channels/$id"
          params={{ id: channel.id }}
          className="mb-4 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
        >
          <ArrowLeft className="size-4" />
          {channel.name}
        </Link>
      )}
      {state === "ready" && isDemoMode && (
        <PrototypeStateBar
          label="Download quota"
          value={quota}
          options={
            [
              { value: "normal", label: "Available" },
              { value: "low", label: "Not enough" },
            ] as const
          }
          onChange={setQuota}
        />
      )}
      <PageHeader
        leading={<RecordingCreatorAvatar recording={rec} size="md" />}
        title={state === "active" ? `${rec.handle} — Live now` : `${rec.handle} — ${rec.title}`}
        subtitle={`TikTok · ${state === "active" ? "Started" : rec.date} at ${rec.time}`}
        action={actions}
      />
      {!isDemoMode && (state === "active" || state === "processing") && (
        <RecordingRealtimeNotice state={realtime.state} lastEventAt={realtime.lastEventAt} />
      )}
      {!isDemoMode &&
        (state === "ready" || state === "failed") &&
        artifactsState.kind === "error" && (
          <div className="mb-4">
            <StateBanner
              tone="warning"
              icon={AlertTriangle}
              title="Could not load the recording file"
              body="The recording exists, but SaveStream could not confirm its stored artifact."
              action={
                <Button size="sm" variant="outline" onClick={() => void artifactsQuery.refetch()}>
                  Retry
                </Button>
              }
            />
          </div>
        )}
      {!isDemoMode &&
        (state === "ready" || state === "failed") &&
        artifactsState.kind === "empty" && (
          <div className="mb-4">
            <StateBanner
              tone="warning"
              icon={AlertTriangle}
              title="Recording file unavailable"
              body="The stored file is no longer available. It may have expired or already been cleaned up."
            />
          </div>
        )}
      {expiringSoon && (
        <div className="mb-4">
          <StateBanner
            tone={rec.expireTone === "critical" ? "error" : "warning"}
            icon={Clock3}
            title={
              rec.expireTone === "critical"
                ? "This recording expires tomorrow"
                : `This recording expires in ${rec.expires}`
            }
            body={
              isDemoMode
                ? `It will be removed from cloud storage when your ${usage.retentionDays}-day retention period ends. Download it to keep a copy.`
                : "It will be removed from cloud storage when its storage period ends. Download it to keep a copy."
            }
            action={
              <Button
                size="sm"
                variant="outline"
                disabled={downloadRecording.isPreparing}
                onClick={download}
              >
                {downloadRecording.isPreparing ? "Preparing…" : "Download"}
              </Button>
            }
          />
        </div>
      )}
      <VideoPlayerShell
        state={state}
        {...(isDemoMode
          ? {}
          : {
              elapsed: rec.duration,
              failedDetail: rec.partialDuration
                ? `${rec.partialDuration} was saved before the recording stopped.`
                : (rec.error ?? "No video was saved for this recording."),
              ...(artifact
                ? {
                    loadSource: () =>
                      playbackLink
                        .mutateAsync(rec.id)
                        .then(({ download: signed }) => signed.url)
                        .catch((error: unknown) => {
                          throw new Error(artifactActionErrorMessage(error));
                        }),
                  }
                : {}),
            })}
      />
      {state === "active" && (
        <div className="mt-4 flex items-center gap-3 rounded-lg border border-success/30 bg-success-subtle p-4 text-sm">
          <Cloud className="size-5 shrink-0 text-success" />
          <div>
            <p className="font-medium">
              Recording runs on our servers. You can safely close this page.
            </p>
            <p className="text-muted-foreground">
              Playback will be available after the livestream ends.
            </p>
          </div>
        </div>
      )}
      {state === "processing" && <ProcessingTimeline status={rec.backendStatus} />}
      {state === "failed" && (
        <div className="mt-4 space-y-3">
          <StateBanner
            tone={
              rec.backendStatus === "stopped" || rec.backendStatus === "missed_no_cloud_slot"
                ? "info"
                : "error"
            }
            title={
              rec.backendStatus === "stopped"
                ? "Recording stopped"
                : rec.backendStatus === "missed_no_cloud_slot"
                  ? t("Recording missed")
                  : "Recording couldn’t be completed"
            }
            body={
              rec.backendStatus === "stopped"
                ? "The recording was stopped before it completed."
                : rec.backendStatus === "missed_no_cloud_slot"
                  ? t(
                      "The livestream ended before a cloud recording slot became available. No credits were charged.",
                    )
                  : rec.error || "Something went wrong while recording this livestream."
            }
            action={
              isDemoMode ? (
                <div className="flex gap-2">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() =>
                      toast.success("Processing queued", {
                        description: "We’ll notify you when the partial recording is ready.",
                      })
                    }
                  >
                    <RotateCcw />
                    Retry processing
                  </Button>
                  <Button size="sm" variant="ghost" asChild>
                    <Link to="/help" hash="contact">
                      Contact support
                    </Link>
                  </Button>
                </div>
              ) : (
                <Button size="sm" variant="ghost" asChild>
                  <Link to="/help" hash="contact">
                    Contact support
                  </Link>
                </Button>
              )
            }
          />
        </div>
      )}
      <div className="mt-6 grid grid-cols-2 gap-px overflow-hidden rounded-lg border bg-border sm:grid-cols-3 lg:grid-cols-6">
        {[
          ["Platform", "TikTok"],
          ["Started", `${rec.date.replace(", 2026", "")} · ${rec.time}`],
          ["Duration", state === "failed" ? `${rec.duration} (partial)` : rec.duration],
          [state === "active" ? "Written" : "File size", rec.size],
          [
            "Resolution",
            artifact?.width && artifact.height
              ? `${artifact.width}×${artifact.height}`
              : rec.resolution,
          ],
          [
            "Stored until",
            state === "active" || state === "processing"
              ? "After processing"
              : rec.expireTone === "critical"
                ? "Tomorrow"
                : rec.expiresDays === null
                  ? "—"
                  : `${rec.expires} left`,
          ],
        ].map(([a, b]) => (
          <div key={a} className="bg-surface p-4">
            <p className="text-xs text-muted-foreground">{a}</p>
            <p className="mt-2 font-mono text-sm font-medium">{b}</p>
          </div>
        ))}
      </div>
      {isDemoMode ? (
        <>
          <UpgradeDialog open={upgrade} onOpenChange={setUpgrade} fileSize={rec.size} />
          <ConfirmDeleteDialog
            open={del}
            onOpenChange={setDel}
            partial={state === "failed"}
            onDeleted={() => navigate({ to: "/recordings" })}
          />
        </>
      ) : (
        <ConfirmDialog
          destructive
          open={del}
          onOpenChange={setDel}
          title="Delete recording?"
          body="This recording will disappear from your library and its stored artifact will be scheduled for cleanup. This action cannot be undone."
          confirmLabel="Delete recording"
          confirmDisabled={deleteRecording.isPending}
          onConfirm={() => {
            void deleteRecording
              .mutateAsync(rec.id)
              .then(() => {
                setDel(false);
                toast.success("Recording deleted");
                void navigate({ to: "/recordings" });
              })
              .catch((error) => {
                toast.error("Could not delete recording", {
                  description: recordingActionErrorMessage(error),
                });
              });
          }}
        />
      )}
    </AppShell>
  );
}

function ProcessingTimeline({ status }: { status: RecordingModel["backendStatus"] }) {
  const { t } = usePreferences();
  const waitingForSlot = status === "waiting_for_cloud_slot";
  const resolving =
    status === "queued" || status === "resolving" || status === "waiting_live" || waitingForSlot;
  const processing = status === "processing";
  const uploading = status === "uploading";

  const stage = resolving ? 0 : processing ? 1 : uploading ? 2 : 3;
  const steps = [
    [
      Activity,
      waitingForSlot
        ? "Waiting for a cloud recording slot"
        : resolving
          ? "Preparing recorder"
          : "Recording completed",
    ],
    [Activity, "Processing video"],
    [Upload, "Uploading"],
    [CheckCircle2, "Ready"],
  ] as const;

  return (
    <div className="mt-5 rounded-lg border p-5">
      <h2 className="font-medium">{t("Finalizing your recording")}</h2>
      <p className="mt-1 text-sm text-muted-foreground">
        {t("This page updates automatically as your recording is processed.")}
      </p>
      <div className="mt-5 grid gap-3 sm:grid-cols-4">
        {steps.map(([Icon, label], index) => {
          const statusLabel = index < stage ? "done" : index === stage ? "active" : "next";
          return (
            <div className="flex items-center gap-2" key={label}>
              <Icon
                className={cn(
                  "size-4",
                  statusLabel === "done"
                    ? "text-success"
                    : statusLabel === "active"
                      ? "animate-pulse text-info"
                      : "text-muted-foreground",
                )}
              />
              <span className={cn("text-sm", statusLabel === "next" && "text-muted-foreground")}>
                {t(label)}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export function UsagePage() {
  return isDemoMode ? <DemoUsagePage /> : <CreditsUsagePage />;
}

export function formatMoneyValue(money: Money, language: string) {
  try {
    const formatter = new Intl.NumberFormat(language, {
      style: "currency",
      currency: money.currency,
    });
    const digits = formatter.resolvedOptions().maximumFractionDigits ?? 2;
    return formatter.format(money.amount_minor / 10 ** digits);
  } catch {
    return `${money.amount_minor} ${money.currency} minor units`;
  }
}

function formatCreditMoney(packageItem: CreditPackageResponse, language: string) {
  return formatMoneyValue(packageItem.price, language);
}

function formatApproxHours(minutes: number | null | undefined, language: string) {
  if (minutes === null || minutes === undefined || minutes <= 0) return null;
  const hours = minutes / 60;
  const value = new Intl.NumberFormat(language, {
    maximumFractionDigits: hours < 10 ? 1 : 0,
  }).format(hours);
  const unit = hours === 1 ? "hour" : "hours";
  return `≈ ${value} ${unit}`;
}

function pricingRuleTitle(rule: PricingResponse["rules"][number], index: number) {
  const description = rule["description"];
  if (typeof description === "string" && description.trim()) return description;
  const code = rule["code"];
  if (typeof code === "string" && code.trim()) return code;
  return `Pricing rule ${index + 1}`;
}

function pricingRuleDetail(rule: PricingResponse["rules"][number]) {
  const unitSeconds = rule["unit_seconds"];
  const creditsPerUnit = rule["credits_per_unit"];
  if (typeof unitSeconds === "number" && typeof creditsPerUnit === "number") {
    const unit = unitSeconds % 60 === 0 ? `${unitSeconds / 60} min` : `${unitSeconds} sec`;
    return `${creditsPerUnit} credit${creditsPerUnit === 1 ? "" : "s"} per ${unit}`;
  }
  return "See the pricing page for details.";
}

function creditTransactionTitle(transaction: CreditTransactionResponse) {
  if (transaction.type === "charge" && transaction.reference_type === "recording") {
    return "Recording";
  }
  if (transaction.type === "grant" && transaction.reference_type === "signup_bonus") {
    return "Free trial credits";
  }
  if (transaction.type === "grant") return "Credits purchased";
  if (transaction.type === "refund") return "Refund";
  if (transaction.type === "adjustment") return "Credit adjustment";
  if (transaction.type === "release") {
    // Held credits never left the balance, so the entry amount is 0; say how
    // many were released instead of showing a confusing "0".
    return transaction.released_credits
      ? `Released ${pluralize(transaction.released_credits, "held credit")}`
      : "Credit hold released";
  }
  return "Credit change";
}

const reservationStatusLabel: Record<CreditReservationResponse["status"], string> = {
  active: "Recording",
  settled: "Charged",
  released: "Returned",
};

function CreditTransactionRow({ transaction }: { transaction: CreditTransactionResponse }) {
  const amount =
    transaction.type === "release" && transaction.amount === 0
      ? "—"
      : transaction.amount > 0
        ? `+${transaction.amount}`
        : String(transaction.amount);
  return (
    <div className="grid gap-2 border-t px-4 py-3 text-sm sm:grid-cols-[1.5fr_.8fr_.8fr_auto] sm:items-center">
      <div>
        <p className="font-medium">{creditTransactionTitle(transaction)}</p>
        <p className="mt-1 text-xs text-muted-foreground">
          {new Date(transaction.created_at).toLocaleString()}
        </p>
      </div>
      <span />
      <span className="text-muted-foreground">Balance {transaction.balance_after}</span>
      <span className="font-mono font-semibold">{amount}</span>
    </div>
  );
}

function CreditReservationRow({ reservation }: { reservation: CreditReservationResponse }) {
  const outstanding = Math.max(
    0,
    reservation.reserved - reservation.settled - reservation.released,
  );
  return (
    <div className="grid gap-2 border-t px-4 py-3 text-sm sm:grid-cols-[1.5fr_repeat(4,.7fr)] sm:items-center">
      <div>
        <Link
          to="/recordings/$id"
          params={{ id: reservation.recording_id }}
          className="font-medium hover:underline"
        >
          Recording
        </Link>
        <p className="mt-1 text-xs text-muted-foreground">
          {new Date(reservation.created_at).toLocaleString()}
        </p>
      </div>
      <span>{reservationStatusLabel[reservation.status]}</span>
      <span className="text-muted-foreground">Held {reservation.reserved}</span>
      <span className="text-muted-foreground">Used {reservation.settled}</span>
      <span className="text-muted-foreground">
        Returned {reservation.status === "active" ? 0 : reservation.released || outstanding}
      </span>
    </div>
  );
}

function CreditsUsagePage() {
  const { t, language } = usePreferences();
  const { query: balanceQuery, state: balanceState } = useCreditBalanceData();
  const { query: transactionsQuery, state: transactionsState } = useCreditTransactionsData();
  const { query: reservationsQuery, state: reservationsState } = useCreditReservationsData();
  const { query: pricingQuery, state: pricingState } = usePricingData();
  const { query: packagesQuery, state: packagesState } = useCreditPackagesData();

  if (
    balanceState.kind === "loading" ||
    transactionsState.kind === "loading" ||
    reservationsState.kind === "loading" ||
    !balanceQuery.data
  ) {
    return (
      <AppShell>
        <PageHeader title="Credits & usage" subtitle="Loading credit account…" />
        <div className="h-40 animate-pulse rounded-lg border bg-muted" aria-busy="true" />
      </AppShell>
    );
  }

  if (balanceState.kind === "error") {
    return (
      <AppShell>
        <PageHeader title="Credits & usage" />
        <ErrorState
          title="Could not load credit balance"
          body="SaveStream could not load your credit balance. Please try again."
          onRetry={() => balanceQuery.refetch()}
        />
      </AppShell>
    );
  }

  const balance = balanceQuery.data;
  const transactions = transactionsQuery.data?.items ?? [];
  const reservations = reservationsQuery.data?.items ?? [];
  const activeReservations = reservations.filter((item) => item.status === "active");
  const packages = packagesQuery.data?.items ?? [];
  const pricing = pricingQuery.data;

  return (
    <AppShell>
      <PageHeader
        title="Credits & usage"
        subtitle="Your credit balance, reserved credits, and recording charges."
        action={
          <Button variant="outline" asChild>
            <Link to="/billing">
              <CreditCard />
              Billing
            </Link>
          </Button>
        }
      />

      <div className="mb-6">
        <StateBanner
          tone="info"
          icon={Gauge}
          title="How credits work"
          body="Credits are used only while a livestream is being recorded, rounded up to the next minute. When a recording starts, SaveStream holds enough credits for it; after it ends you are charged only for the time recorded and the rest is returned."
        />
      </div>

      <div className="grid overflow-hidden rounded-lg border sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Available credits"
          value={String(balance.available)}
          detail="Ready to use for recordings"
          icon={Zap}
        />
        <StatCard
          label="Total balance"
          value={String(balance.posted)}
          detail="Including credits on hold"
          icon={CreditCard}
        />
        <StatCard
          label="On hold"
          value={String(balance.reserved)}
          detail="For recordings in progress"
          icon={Clock3}
        />
        <StatCard
          label="Recordings in progress"
          value={String(activeReservations.length)}
          detail="Using credits right now"
          icon={Radio}
        />
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <section className="rounded-lg border bg-surface p-5">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h2 className="font-medium">{t("Current pricing")}</h2>
              <p className="mt-1 text-sm text-muted-foreground">What recordings cost.</p>
            </div>
          </div>
          {pricingState.kind === "error" ? (
            <div className="mt-5">
              <StateBanner
                tone="warning"
                title="Pricing unavailable"
                body="Pricing could not be loaded. Please try again."
                action={
                  <Button size="sm" variant="outline" onClick={() => void pricingQuery.refetch()}>
                    Retry
                  </Button>
                }
              />
            </div>
          ) : pricing ? (
            <div className="mt-5 space-y-3">
              {pricing.rules.length ? (
                pricing.rules.map((rule, index) => (
                  <div key={String(rule["code"] ?? index)} className="rounded-md border p-4">
                    <p className="text-sm font-medium">{pricingRuleTitle(rule, index)}</p>
                    <p className="mt-1 text-xs text-muted-foreground">{pricingRuleDetail(rule)}</p>
                  </div>
                ))
              ) : (
                <p className="text-sm text-muted-foreground">
                  Pricing details are not available right now.
                </p>
              )}
            </div>
          ) : (
            <div className="mt-5 h-24 animate-pulse rounded-md bg-muted" />
          )}
        </section>

        <section className="rounded-lg border bg-surface p-5">
          <h2 className="font-medium">Credit packages</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Available packages. Credits never expire.
          </p>
          {packagesState.kind === "error" ? (
            <div className="mt-5">
              <StateBanner
                tone="warning"
                title="Packages unavailable"
                body="SaveStream could not load the current credit packages."
                action={
                  <Button size="sm" variant="outline" onClick={() => void packagesQuery.refetch()}>
                    Retry
                  </Button>
                }
              />
            </div>
          ) : packages.length ? (
            <div className="mt-5 space-y-3">
              {packages.map((item) => (
                <div
                  key={item.id}
                  className="flex items-center justify-between gap-4 rounded-md border p-4"
                >
                  <div>
                    <p className="text-sm font-medium">{item.name}</p>
                    <p className="mt-1 text-xs text-muted-foreground">
                      {pluralize(item.credits, "credit")}
                      {formatApproxHours(item.cloud_minutes, language)
                        ? ` · ${formatApproxHours(item.cloud_minutes, language)}`
                        : ""}
                    </p>
                  </div>
                  <p className="font-mono font-semibold">{formatCreditMoney(item, language)}</p>
                </div>
              ))}
              <Link to="/billing" className="text-xs font-medium text-primary hover:underline">
                Buy credits in Billing
              </Link>
            </div>
          ) : packagesState.kind === "empty" ? (
            <p className="mt-5 text-sm text-muted-foreground">
              No active credit packages are available right now.
            </p>
          ) : (
            <div className="mt-5 h-24 animate-pulse rounded-md bg-muted" />
          )}
        </section>
      </div>

      <section className="mt-8 rounded-lg border bg-surface">
        <div className="border-b p-5">
          <h2 className="font-medium">Credits held for recordings</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Credits held while a recording runs, what it used, and what was returned.
          </p>
        </div>
        {reservationsState.kind === "error" ? (
          <div className="p-5">
            <StateBanner
              tone="warning"
              title="Could not load credit holds"
              body="Please try again in a moment."
              action={
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => void reservationsQuery.refetch()}
                >
                  Retry
                </Button>
              }
            />
          </div>
        ) : reservations.length ? (
          reservations.map((reservation) => (
            <CreditReservationRow key={reservation.id} reservation={reservation} />
          ))
        ) : (
          <p className="p-5 text-sm text-muted-foreground">No recordings have used credits yet.</p>
        )}
      </section>

      <section className="mt-8 rounded-lg border bg-surface">
        <div className="border-b p-5">
          <h2 className="font-medium">Credit history</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Credits added to and used from your account.
          </p>
        </div>
        {transactionsState.kind === "error" ? (
          <div className="p-5">
            <StateBanner
              tone="warning"
              title="Could not load credit history"
              body="Please try again in a moment."
              action={
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => void transactionsQuery.refetch()}
                >
                  Retry
                </Button>
              }
            />
          </div>
        ) : transactions.length ? (
          transactions.map((transaction) => (
            <CreditTransactionRow key={transaction.id} transaction={transaction} />
          ))
        ) : (
          <p className="p-5 text-sm text-muted-foreground">No credit activity yet.</p>
        )}
      </section>
    </AppShell>
  );
}

function DemoUsagePage() {
  const { t } = usePreferences();
  const { query: usageQuery, state: usageState } = useUsageData();
  const { query: recordingsQuery } = useRecordingsData();
  const [mock, setMock] = useState<(typeof usageStates)[number]["value"]>("normal");

  if (usageState.kind === "loading" || !usageQuery.data) {
    return (
      <AppShell>
        <PageHeader title="Usage" subtitle="Loading current usage…" />
        <div className="h-40 animate-pulse rounded-lg border bg-muted" aria-busy="true" />
      </AppShell>
    );
  }

  if (usageState.kind === "error") {
    return (
      <AppShell>
        <PageHeader title="Usage" />
        <ErrorState
          title="Could not load usage"
          body="The usage repository returned an error."
          onRetry={() => usageQuery.refetch()}
        />
      </AppShell>
    );
  }

  const usage = usageQuery.data.summary;
  const dailyRecordingHours = usageQuery.data.dailyRecordingHours;
  const usageRecordings = recordingsQuery.data ?? [];
  const hours = mock === "warning" ? 40.2 : mock === "reached" ? 50 : usage.recordingHours.used;
  const dl = mock === "download" ? 100 : usage.downloadGb.used;
  const ch = mock === "channels" ? usage.channels.limit : usage.channels.used;
  const hp = Math.round((hours / usage.recordingHours.limit) * 100);
  const dp = Math.round((dl / usage.downloadGb.limit) * 100);
  const cp = Math.round((ch / usage.channels.limit) * 100);
  const upgradeBtn = (
    <Button size="sm" asChild>
      <Link to="/billing">{t("Upgrade plan")}</Link>
    </Button>
  );
  return (
    <AppShell>
      <PageHeader
        title="Usage"
        subtitle={`Current period: ${usage.periodStart.replace(", 2026", "")} – ${usage.periodEnd} · Resets ${usage.resetsOn}`}
        action={
          <Button variant="outline" asChild>
            <Link to="/billing">
              <CreditCard />
              Billing
            </Link>
          </Button>
        }
      />
      <PrototypeStateBar value={mock} options={usageStates} onChange={setMock} />
      <div className="mb-6 space-y-3">
        {mock === "warning" && (
          <StateBanner
            tone="warning"
            title="Your cloud recording allowance is running low."
            body={`${hours} of ${usage.recordingHours.limit} demo hours used. Buy more cloud hours when you need them.`}
            action={upgradeBtn}
          />
        )}
        {mock === "reached" && (
          <StateBanner
            tone="error"
            title="Recording quota reached"
            body={
              <>
                Automatic recording is paused until your quota resets or you upgrade your plan.
                Monitoring continues, but new livestreams won’t be recorded until {usage.resetsOn}.
              </>
            }
            action={upgradeBtn}
          />
        )}
        {mock === "download" && (
          <StateBanner
            tone="error"
            title="Download bandwidth exhausted"
            body={`Downloads are unavailable until your quota resets on ${usage.resetsOn}. Recording and browser playback are not affected.`}
            action={upgradeBtn}
          />
        )}
        {mock === "channels" && (
          <StateBanner
            tone="warning"
            title="Monitored channel limit reached"
            body={`Your plan allows ${usage.channels.limit} monitored channels. Remove a channel or upgrade to add another.`}
            action={
              <Button size="sm" variant="outline" asChild>
                <Link to="/channels">Manage channels</Link>
              </Button>
            }
          />
        )}
      </div>
      <div className="grid overflow-hidden rounded-lg border sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Recording hours"
          value={`${hours} / ${usage.recordingHours.limit}`}
          detail={`${hp}% used`}
          icon={Clock3}
          progress={hp}
        />
        <StatCard
          label="Concurrent limit"
          value={`${usage.concurrent.limit} streams`}
          detail={`${usage.concurrent.active} recording now`}
          icon={Radio}
        />
        <StatCard
          label="Download bandwidth"
          value={`${dl} / ${usage.downloadGb.limit} GB`}
          detail={`${dp}% used`}
          icon={Download}
          progress={dp}
        />
        <StatCard
          label="Retention"
          value={`${usage.retentionDays} days`}
          detail={`${user.plan} plan`}
          icon={HardDrive}
        />
      </div>
      <div className="mt-6 grid gap-6 lg:grid-cols-[1.4fr_.6fr]">
        <section className="rounded-lg border bg-surface p-5">
          <div className="flex items-center justify-between">
            <h2 className="font-medium">{t("Daily recording hours")}</h2>
            <span className="text-xs text-muted-foreground">September 2026</span>
          </div>
          <div
            className="mt-8 flex h-56 items-end gap-1 border-b border-l px-2 sm:gap-2"
            role="img"
            aria-label="Bar chart of daily recording hours in September"
          >
            {dailyRecordingHours.map((v, i) => (
              <div
                key={i}
                title={`Sep ${i + 1}: ${v}h`}
                className="group relative flex-1 rounded-t-sm bg-primary/75 hover:bg-primary"
                style={{ height: `${(v / 5) * 100}%` }}
              >
                <span className="absolute -top-6 left-1/2 hidden -translate-x-1/2 rounded bg-foreground px-1 font-mono text-[9px] text-background group-hover:block">
                  {v}h
                </span>
              </div>
            ))}
          </div>
        </section>
        <section className="rounded-lg border bg-surface p-5">
          <h2 className="font-medium">{t("Plan limits")}</h2>
          <div className="mt-6 space-y-6">
            {(
              [
                ["Recording hours", `${hours} of ${usage.recordingHours.limit} hours`, hp],
                ["Download bandwidth", `${dl} of ${usage.downloadGb.limit} GB`, dp],
                ["Monitored channels", `${ch} of ${usage.channels.limit} channels`, cp],
              ] as const
            ).map(([a, b, c]) => (
              <div key={a}>
                <div className="mb-2 flex justify-between text-xs">
                  <span>{a}</span>
                  <span
                    className={cn(
                      "font-mono text-muted-foreground",
                      c >= 100 && "text-destructive",
                      c >= 80 && c < 100 && "text-warning-foreground",
                    )}
                  >
                    {b}
                  </span>
                </div>
                <UsageProgress value={c} tone={c >= 80 ? "warning" : "primary"} />
              </div>
            ))}
          </div>
          <div className="mt-6 border-t pt-5 text-xs leading-5 text-muted-foreground">
            <p className="font-medium text-foreground">About concurrent recordings</p>
            <p className="mt-1">
              Up to {usage.concurrent.limit} livestreams can record at the same time. If another
              monitored channel goes live while both slots are in use, it waits for a free slot —
              the start of that livestream may not be recorded.
            </p>
          </div>
        </section>
      </div>
      <section className="mt-8">
        <SectionTitle title="Usage by recording" />
        <div className="hidden overflow-hidden rounded-lg border sm:block">
          <div className="grid grid-cols-4 bg-surface-subtle px-4 py-2 text-[11px] uppercase text-muted-foreground">
            <span>{t("Date")}</span>
            <span>Channel</span>
            <span>{t("Duration")}</span>
            <span>{t("Size")}</span>
          </div>
          {usageRecordings.map((r) => (
            <div className="grid grid-cols-4 border-t px-4 py-3 text-sm" key={r.id}>
              <span>{r.date}</span>
              <span>{r.handle}</span>
              <span className="font-mono">{r.duration}</span>
              <span className="font-mono">{r.size}</span>
            </div>
          ))}
        </div>
        <div className="divide-y rounded-lg border sm:hidden">
          {usageRecordings.map((r) => (
            <div key={r.id} className="flex justify-between p-3 text-sm">
              <div>
                <p className="font-medium">{r.handle}</p>
                <p className="text-xs text-muted-foreground">{r.date}</p>
              </div>
              <div className="text-right font-mono text-xs">
                <p>{r.duration}</p>
                <p className="text-muted-foreground">{r.size}</p>
              </div>
            </div>
          ))}
        </div>
      </section>
    </AppShell>
  );
}
export function BillingPage() {
  return isDemoMode ? <DemoBillingPage /> : <CreditBillingPage />;
}

function paymentStatusLabel(status: PaymentStatusValue) {
  return status
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function paymentStatusClass(status: PaymentStatusValue) {
  if (status === "paid") return "bg-success-subtle text-success";
  if (status === "pending" || status === "created" || status === "partially_refunded") {
    return "bg-warning-subtle text-warning-foreground";
  }
  if (status === "failed") return "bg-recording-subtle text-destructive";
  return "bg-muted text-muted-foreground";
}

function PaymentOrderRow({
  order,
  language,
  onContinue,
  pending,
  checkoutOpen,
}: {
  order: PaymentOrderResponse;
  language: string;
  onContinue: (id: string) => void;
  pending: boolean;
  checkoutOpen: boolean;
}) {
  return (
    <div className="grid gap-3 border-t px-5 py-4 text-sm sm:grid-cols-[1.3fr_.7fr_.7fr_auto] sm:items-center">
      <div>
        <p className="font-medium">{pluralize(order.credits, "credit")}</p>
        <p className="mt-1 text-xs text-muted-foreground">
          {new Date(order.created_at).toLocaleString()}
        </p>
      </div>
      <span className="font-mono">{formatMoneyValue(order.amount, language)}</span>
      <span
        className={cn(
          "w-fit rounded-md px-2 py-1 text-xs font-medium",
          paymentStatusClass(order.status),
        )}
      >
        {paymentStatusLabel(order.status)}
      </span>
      {checkoutOpen && isAwaitingPaymentConfirmation(order.status) ? (
        <Button size="sm" variant="outline" disabled={pending} onClick={() => onContinue(order.id)}>
          <ExternalLink />
          Open checkout
        </Button>
      ) : (
        <span />
      )}
    </div>
  );
}

function CreditBillingPage() {
  const { language } = usePreferences();
  const { query: balanceQuery, state: balanceState } = useCreditBalanceData();
  const { query: packagesQuery, state: packagesState } = useCreditPackagesData();
  const { query: ordersQuery, state: ordersState } = usePaymentOrdersData();
  const checkout = useBillingCheckoutMutation();
  const capture = usePayPalCaptureMutation();
  const billingCheckoutEnabled = useCheckoutChannels().web;
  const [activePurchase, setActivePurchase] = useState<string | null>(null);
  const [paypalCheckout, setPayPalCheckout] = useState<{
    paymentOrderId: string;
    providerOrderId: string;
    credits: number;
    amount: Money;
  } | null>(null);

  const redirectToCheckout = async (input: BillingCheckoutInput, activeId: string) => {
    setActivePurchase(activeId);
    try {
      const result = await checkout.mutateAsync(input);
      if (result.payment_order.provider === "paypal") {
        const providerOrderId = result.payment_order.provider_reference;
        if (!providerOrderId) {
          throw new Error("PayPal did not return an order ID.");
        }
        setPayPalCheckout({
          paymentOrderId: result.payment_order.id,
          providerOrderId,
          credits: result.payment_order.credits,
          amount: result.payment_order.amount,
        });
        setActivePurchase(null);
        return;
      }
      window.location.assign(result.checkout_url);
    } catch (error) {
      toast.error("Could not open secure checkout", {
        description: billingActionErrorMessage(error),
      });
      setActivePurchase(null);
    }
  };

  if (balanceState.kind === "loading" || !balanceQuery.data) {
    return (
      <AppShell>
        <PageHeader title="Billing" subtitle="Loading credit account…" />
        <div className="h-40 animate-pulse rounded-lg border bg-muted" aria-busy="true" />
      </AppShell>
    );
  }

  if (balanceState.kind === "error") {
    return (
      <AppShell>
        <PageHeader title="Billing" />
        <ErrorState
          title="Could not load billing balance"
          body="SaveStream could not load your credit balance. Please try again."
          onRetry={() => balanceQuery.refetch()}
        />
      </AppShell>
    );
  }

  const balance = balanceQuery.data;
  const packages = packagesQuery.data?.items ?? [];
  const orders = ordersQuery.data?.items ?? [];

  return (
    <AppShell>
      <PageHeader
        title="Billing"
        subtitle={
          billingCheckoutEnabled
            ? "Buy credits for cloud recording. One-time purchase, no subscription."
            : "Review credit packages and your balance. Online checkout is not open yet."
        }
        action={
          <Button variant="outline" asChild>
            <Link to="/usage">View credits & usage</Link>
          </Button>
        }
      />

      {!billingCheckoutEnabled && (
        <div className="mb-6">
          <StateBanner
            tone="info"
            icon={ShieldCheck}
            title="Credit purchases are coming soon"
            body="Online checkout is not open yet. Your free trial credits work as usual, and you can contact support@savestream.online with any questions."
          />
        </div>
      )}

      <div className="grid overflow-hidden rounded-lg border sm:grid-cols-3">
        <StatCard
          label="Available credits"
          value={String(balance.available)}
          detail="Ready to use for recordings"
          icon={Zap}
        />
        <StatCard
          label="Total balance"
          value={String(balance.posted)}
          detail="Including credits on hold"
          icon={CreditCard}
        />
        <StatCard
          label="On hold"
          value={String(balance.reserved)}
          detail="For recordings in progress"
          icon={Clock3}
        />
      </div>

      <section className="mt-8">
        <div className="mb-4">
          <h2 className="text-lg font-semibold">Credit packages</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            {billingCheckoutEnabled
              ? "Choose a package and pay securely with PayPal. Credits never expire."
              : "Preview the available packages. Checkout will become available after payment readiness checks are complete."}
          </p>
        </div>

        {packagesState.kind === "error" ? (
          <StateBanner
            tone="warning"
            title="Packages unavailable"
            body="SaveStream could not load the current credit packages."
            action={
              <Button size="sm" variant="outline" onClick={() => void packagesQuery.refetch()}>
                Retry
              </Button>
            }
          />
        ) : packages.length ? (
          <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
            {packages.map((item) => {
              const loading = checkout.isPending && activePurchase === item.id;
              return (
                <div key={item.id} className="rounded-lg border bg-surface p-6">
                  <p className="text-lg font-semibold">{item.name}</p>
                  <p className="mt-3 font-mono text-3xl font-semibold">
                    {formatCreditMoney(item, language)}
                  </p>
                  <p className="mt-2 text-sm text-muted-foreground">
                    {pluralize(item.credits, "credit")}
                    {formatApproxHours(item.cloud_minutes, language)
                      ? ` · ${formatApproxHours(item.cloud_minutes, language)}`
                      : ""}
                  </p>
                  <Button
                    className="mt-6 w-full"
                    disabled={!billingCheckoutEnabled || checkout.isPending}
                    onClick={() =>
                      void redirectToCheckout({ kind: "package", packageId: item.id }, item.id)
                    }
                  >
                    <CreditCard />
                    {loading
                      ? "Opening checkout…"
                      : billingCheckoutEnabled
                        ? "Buy credits"
                        : "Coming soon"}
                  </Button>
                </div>
              );
            })}
          </div>
        ) : packagesState.kind === "empty" ? (
          <EmptyState
            icon={CreditCard}
            title="No packages available"
            body="Credit packages are not available right now. Please check back soon."
          />
        ) : (
          <div className="grid gap-5 md:grid-cols-2">
            <div className="h-44 animate-pulse rounded-lg border bg-muted" />
            <div className="h-44 animate-pulse rounded-lg border bg-muted" />
          </div>
        )}
      </section>

      <section className="mt-8 overflow-hidden rounded-lg border bg-surface">
        <div className="flex items-start justify-between gap-4 p-5">
          <div>
            <h2 className="font-medium">Purchase history</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Your credit purchases and their payment status.
            </p>
          </div>
          <Button
            size="sm"
            variant="outline"
            disabled={ordersQuery.isFetching}
            onClick={() => void ordersQuery.refetch()}
          >
            <RotateCcw />
            Refresh
          </Button>
        </div>
        {ordersState.kind === "error" ? (
          <div className="border-t p-5">
            <StateBanner
              tone="warning"
              title="Payment history unavailable"
              body="Please try again in a moment."
              action={
                <Button size="sm" variant="outline" onClick={() => void ordersQuery.refetch()}>
                  Retry
                </Button>
              }
            />
          </div>
        ) : orders.length ? (
          orders.map((order) => (
            <PaymentOrderRow
              key={order.id}
              order={order}
              language={language}
              pending={checkout.isPending}
              checkoutOpen={billingCheckoutEnabled}
              onContinue={(orderId) => void redirectToCheckout({ kind: "order", orderId }, orderId)}
            />
          ))
        ) : (
          <p className="border-t p-5 text-sm text-muted-foreground">No purchases yet.</p>
        )}
      </section>

      <div className="mt-8">
        <StateBanner
          tone="info"
          title="When do credits arrive?"
          body="Credits are added immediately after SaveStream securely captures the approved PayPal order. Refresh this page if a purchase still shows as pending."
        />
      </div>

      <Dialog
        open={paypalCheckout !== null}
        onOpenChange={(open) => {
          if (!open && !capture.isPending) setPayPalCheckout(null);
        }}
      >
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Pay securely with PayPal</DialogTitle>
            <DialogDescription>
              {paypalCheckout
                ? `${pluralize(paypalCheckout.credits, "credit")} · ${formatMoneyValue(
                    paypalCheckout.amount,
                    language,
                  )}`
                : "Complete your one-time credit purchase."}
            </DialogDescription>
          </DialogHeader>
          {paypalCheckout ? (
            <PayPalCheckoutButtons
              providerOrderId={paypalCheckout.providerOrderId}
              onApprove={async (providerOrderId) => {
                const order = await capture.mutateAsync({
                  paymentOrderId: paypalCheckout.paymentOrderId,
                  providerOrderId,
                });
                toast.success("Payment captured", {
                  description: `${pluralize(order.credits, "credit")} added to your SaveStream account.`,
                });
                setPayPalCheckout(null);
              }}
              onCancel={() => {
                setPayPalCheckout(null);
                toast("PayPal checkout cancelled. No credits were charged.");
              }}
              onError={(error) => {
                toast.error("PayPal checkout could not be completed", {
                  description: billingActionErrorMessage(error),
                });
              }}
            />
          ) : null}
          {capture.isPending ? (
            <p className="text-sm text-muted-foreground">Confirming payment and adding credits…</p>
          ) : null}
        </DialogContent>
      </Dialog>
    </AppShell>
  );
}

function DemoBillingPage() {
  const { t, language } = usePreferences();
  const packages = [
    {
      id: "starter",
      name: "Starter",
      credits: 3_000,
      cloudMinutes: 3_000,
      price: { amount_minor: 999, currency: "USD" } satisfies Money,
    },
    {
      id: "standard",
      name: "Standard",
      credits: 9_000,
      cloudMinutes: 9_000,
      price: { amount_minor: 2_499, currency: "USD" } satisfies Money,
    },
    {
      id: "premium",
      name: "Premium",
      credits: 24_000,
      cloudMinutes: 24_000,
      price: { amount_minor: 5_999, currency: "USD" } satisfies Money,
    },
  ] as const;

  return (
    <AppShell>
      <PageHeader
        title="Billing"
        subtitle={t(
          "One-time cloud-hour purchases. No subscription and nothing renews automatically.",
        )}
      />

      <div className="mb-6">
        <StateBanner
          tone="info"
          title={t("Free web trial")}
          body={t(
            "Free web accounts get 10 trial credits after email verification and can monitor up to 3 channels.",
          )}
        />
      </div>

      <div className="grid overflow-hidden rounded-lg border sm:grid-cols-3">
        <StatCard label="Plan" value={t("Free")} detail={t("No recurring fee")} icon={Sparkles} />
        <StatCard
          label="Trial credits"
          value="10"
          detail={t("10 minutes of cloud recording")}
          icon={Zap}
        />
        <StatCard
          label="Monitored channels"
          value="0 / 3"
          detail={t("Free web limit")}
          icon={Radio}
        />
      </div>

      <section className="mt-8">
        <div className="mb-4">
          <h2 className="text-lg font-semibold">{t("One-time hour packs")}</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            {t("Credits never expire. Buy more whenever you need additional cloud recording time.")}
          </p>
        </div>

        <div className="grid gap-5 md:grid-cols-3">
          {packages.map((item) => (
            <div key={item.id} className="rounded-lg border bg-surface p-6">
              <p className="text-lg font-semibold">{item.name}</p>
              <p className="mt-3 font-mono text-3xl font-semibold">
                {formatMoneyValue(item.price, language)}
              </p>
              <p className="mt-2 text-sm text-muted-foreground">
                {item.credits.toLocaleString(language)} credits ·{" "}
                {formatApproxHours(item.cloudMinutes, language)}
              </p>
              <Button className="mt-6 w-full" asChild>
                <Link to="/billing/success" search={{ order_id: "demo-paid" }}>
                  <CreditCard />
                  {t("Buy once")}
                </Link>
              </Button>
            </div>
          ))}
        </div>
      </section>
    </AppShell>
  );
}
export function AdminSystemPage() {
  return isDemoMode ? <DemoAdminSystemPage /> : <ProductionAdminSystemPage />;
}

function ProductionAdminSystemPage() {
  const snapshot = useAdminOperationalSnapshotData();

  if (snapshot.isPending) {
    return (
      <AppShell>
        <PageHeader title="System" subtitle="Loading backend operational state…" />
        <div className="h-48 animate-pulse rounded-lg border bg-muted" aria-busy="true" />
      </AppShell>
    );
  }

  if (snapshot.isError || !snapshot.data) {
    return (
      <AppShell>
        <PageHeader title="System" />
        <ErrorState
          title="Could not load operational state"
          body="SaveStream could not load the admin operations snapshot."
          onRetry={() => snapshot.refetch()}
        />
      </AppShell>
    );
  }

  const data = snapshot.data;
  const attention =
    data.failed_recordings_recent +
    data.pending_outbox_events +
    data.unprocessed_payment_events +
    data.paused_error_watches;

  return (
    <AppShell>
      <PageHeader
        title="System"
        subtitle="Backend-authoritative operational counters. Refreshes every 10 seconds while this page is open."
        action={
          <Button
            variant="outline"
            disabled={snapshot.isFetching}
            onClick={() => void snapshot.refetch()}
          >
            <RotateCcw />
            {snapshot.isFetching ? "Refreshing…" : "Refresh"}
          </Button>
        }
      />

      <div className="mb-6">
        <AdminGlobalSearch />
      </div>

      {attention > 0 && (
        <div className="mb-6">
          <StateBanner
            tone="warning"
            icon={AlertTriangle}
            title="Operational attention required"
            body="One or more backend counters are non-zero. Use Jobs and Audit to inspect affected recordings and administrative events."
          />
        </div>
      )}

      <div className="grid overflow-hidden rounded-lg border sm:grid-cols-2 xl:grid-cols-3">
        <StatCard
          label="Active recordings"
          value={String(data.active_recordings)}
          detail="Backend active recording states"
          icon={Radio}
        />
        <StatCard
          label="Recent failed recordings"
          value={String(data.failed_recordings_recent)}
          detail="Within the backend failure window"
          icon={AlertTriangle}
        />
        <StatCard
          label="Pending outbox events"
          value={String(data.pending_outbox_events)}
          detail="Ready but not yet published"
          icon={List}
        />
        <StatCard
          label="Unprocessed payment events"
          value={String(data.unprocessed_payment_events)}
          detail="Provider events awaiting processing"
          icon={CreditCard}
        />
        <StatCard
          label="Pending payment orders"
          value={String(data.pending_payment_orders)}
          detail="Orders currently pending"
          icon={Clock3}
        />
        <StatCard
          label="Paused error watches"
          value={String(data.paused_error_watches)}
          detail="Watches paused by repeated errors"
          icon={Activity}
        />
      </div>

      <div className="mt-8">
        <AdminOwnerAccessPanel />
      </div>

      <section className="mt-8 rounded-lg border bg-surface p-5">
        <h2 className="font-medium">What this snapshot does not expose</h2>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">
          The admin operations API does not expose per-worker CPU, memory, heartbeat, raw service
          health, storage totals, or secret-backed metrics. This page deliberately does not invent
          those values or call the protected /metrics endpoint from the browser.
        </p>
      </section>
    </AppShell>
  );
}

function DemoAdminSystemPage() {
  const { t } = usePreferences();
  return (
    <AppShell>
      <PageHeader title="System" subtitle="Illustrative admin metrics for the frontend demo." />
      <div className="grid overflow-hidden rounded-lg border sm:grid-cols-2 xl:grid-cols-3">
        {[
          ["Active workers", "4 / 4", Server],
          ["Active recordings", "1", Radio],
          ["Queue depth", "2", List],
          ["Failed jobs · 24h", "1", AlertTriangle],
          ["Storage used", "8.2 TB", HardDrive],
          ["API errors · 1h", "0.08%", Activity],
        ].map(([a, b, I]) => (
          <StatCard
            key={String(a)}
            label={String(a)}
            value={String(b)}
            detail="Demo fixture"
            icon={I as ElementType}
          />
        ))}
      </div>
      <div className="mt-8">
        <AdminOwnerAccessPanel />
      </div>
      <section className="mt-8 rounded-lg border bg-surface">
        <div className="border-b p-5">
          <h2 className="font-medium">{t("Service health")}</h2>
        </div>
        <div className="grid sm:grid-cols-2">
          {["API", "Redis", "Database", "Storage", "Workers 4/4 online"].map((x) => (
            <div
              key={x}
              className="flex items-center justify-between border-b p-4 text-sm sm:odd:border-r"
            >
              <span>{x}</span>
              <AdminHealthBadge />
            </div>
          ))}
        </div>
      </section>
    </AppShell>
  );
}
export function PricingPage() {
  if (isDemoMode) return <DemoPricingPage />;
  return <CreditPricingPage />;
}

function minutesPerCredit(rate: PublicRecordingRate) {
  return rate.unit_seconds / 60 / rate.credits_per_unit;
}

export function formatRecordingTime(minutes: number, _language: Language = "en") {
  if (minutes >= 120 && minutes % 60 === 0) return `${minutes / 60} hours`;
  if (minutes >= 60) return `${Math.floor(minutes / 60)} h ${minutes % 60} min`;
  return pluralize(minutes, "minute");
}

function rateSentence(rate: PublicRecordingRate | null, _language: Language) {
  if (!rate || rate.credits_per_unit === 0) return null;
  const minutes = minutesPerCredit(rate);
  return `1 credit = ${minutes === 1 ? "1 minute" : `${minutes} minutes`} of cloud recording`;
}

function packageLimits(pricing: PublicPricingResponse | undefined, _language: Language) {
  const lines: string[] = [];
  const channels = pricing?.max_channels_per_user;
  const parallel = pricing?.max_concurrent_recordings_per_user;
  if (channels) {
    lines.push(`Monitor up to ${channels} channels`);
  }
  if (parallel) {
    lines.push(
      parallel === 1
        ? "Record 1 livestream at a time"
        : `Record up to ${parallel} livestreams at the same time`,
    );
  }
  const paidDays = pricing?.recording_retention_days;
  const trialDays = pricing?.trial_recording_retention_days;
  if (paidDays) {
    lines.push(
      trialDays && trialDays !== paidDays
        ? `Recordings stored for ${pluralize(paidDays, "day")} (${pluralize(trialDays, "day")} on the free trial)`
        : `Recordings stored for ${pluralize(paidDays, "day")}`,
    );
  }
  return lines;
}

const includedInEveryPackage = [
  "Automatic live detection for every channel you add",
  "Cloud recording — no computer or browser needs to stay open",
  "Watch in the browser or download the video file",
  "Credits never expire",
];

const paymentFaqs = [
  {
    q: "Who processes my payment?",
    a: "PayPal processes every purchase. SaveStream does not see or store your full card details.",
  },
  {
    q: "Is this a subscription?",
    a: "No. Each pack is a one-time purchase. Nothing renews and you are never charged again unless you buy another pack.",
  },
  {
    q: "Do credits expire?",
    a: "No. Unused credits stay in your balance until you use them.",
  },
  {
    q: "My payment shows as pending. What now?",
    a: "Some PayPal payments take a few minutes to confirm. Credits are added automatically as soon as PayPal confirms the payment. A payment PayPal never completes is closed after 24 hours without charging credits. If you were charged and see no credits, contact support with your PayPal transaction ID.",
  },
  {
    q: "Who issues my receipt?",
    a: "PayPal issues your receipt. Keep the PayPal transaction ID from it — you need it for any billing request.",
  },
  {
    q: "Can I get a refund?",
    a: "Email support@savestream.online with your account email, the PayPal transaction ID and the reason. We review each request individually; refunds are not automatic. Credits already used for recordings may reduce or rule out a refund, and free trial credits can’t be refunded.",
  },
] as const;

function formatPerHour(value: number, currency: string, language: string) {
  try {
    return new Intl.NumberFormat(language, {
      style: "currency",
      currency,
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(value);
  } catch {
    return value.toFixed(2);
  }
}

function CreditPricingPage() {
  const { language, t } = usePreferences();
  const { status } = useAuth();
  const authenticated = status === "authenticated";
  const { query, state } = usePublicPricingData();
  const pricing = query.data;
  const rate = pricing?.recording_rate ?? null;
  const rateLine = rateSentence(rate, language);
  const ctaTo = authenticated ? "/billing" : "/sign-up";
  const channels = useCheckoutChannels();
  const [hoursPerWeek, setHoursPerWeek] = useState(8);
  const [openFaq, setOpenFaq] = useState(0);
  const packages = pricing?.packages ?? [];
  const recommended = recommendPack(packages, hoursPerWeek);
  const recommendedPack = recommended >= 0 ? packages[recommended] : undefined;
  const recommendedHours = recommendedPack ? packHours(recommendedPack) : null;
  const basePerHour = packages[0] ? packPricePerHour(packages[0]) : null;
  const bestPerHour = Math.min(
    ...packages.map((item) => packPricePerHour(item) ?? Number.POSITIVE_INFINITY),
  );
  const trialMinutes =
    pricing && rate && rate.credits_per_unit > 0 && pricing.signup_credits > 0
      ? pricing.signup_credits * minutesPerCredit(rate)
      : null;
  const hourRange = packages.map(packHours).filter((value): value is number => value !== null);

  const comparison: [string, string, string][] = [
    [
      "Recording time",
      pricing?.signup_credits
        ? `${pricing.signup_credits} credits${trialMinutes ? ` (${formatRecordingTime(trialMinutes)})` : ""}`
        : "—",
      hourRange.length
        ? `${Math.round(Math.min(...hourRange))}–${Math.round(Math.max(...hourRange))} hours per pack`
        : "Depends on the pack",
    ],
    ["Automatic cloud recording", "After your first purchase", "Included"],
    ["Payment needed", "No", "PayPal, one time"],
    [
      "Channels monitored",
      pricing?.free_max_channels_per_user
        ? `Up to ${pricing.free_max_channels_per_user}`
        : "Limited",
      pricing?.max_channels_per_user ? `Up to ${pricing.max_channels_per_user}` : "More",
    ],
    [
      "Recordings at the same time",
      "—",
      pricing?.max_concurrent_recordings_per_user
        ? `Up to ${pricing.max_concurrent_recordings_per_user}`
        : "Several",
    ],
    [
      "Storage",
      pricing?.trial_recording_retention_days
        ? pluralize(pricing.trial_recording_retention_days, "day")
        : "Limited",
      pricing?.recording_retention_days
        ? pluralize(pricing.recording_retention_days, "day")
        : "Limited",
    ],
    ["Checking offline channels", "Free", "Free"],
    ["Playback & download", "Included", "Included"],
    ["Credit expiry", "Never", "Never"],
  ];

  return (
    <>
      <PublicHeader />
      <main className="pt-[72px]">
        <section className="relative overflow-hidden">
          <div aria-hidden className="hero-glow" />
          <div className="relative mx-auto flex max-w-[1200px] flex-col items-center gap-[18px] px-6 pb-14 pt-20 text-center">
            <span className="text-xs font-bold uppercase tracking-[.08em] text-accent-ink">
              {t("Pricing")}
            </span>
            <h1 className="max-w-[820px] text-[clamp(36px,4.4vw,56px)] font-extrabold leading-[1.05] tracking-[-.035em]">
              {t("Simple, pay-as-you-go pricing")}
            </h1>
            <p className="max-w-[600px] text-lg leading-relaxed text-muted-foreground">
              {t(
                "Buy credit packs once and use them whenever your channels go live. No subscription and no monthly reset.",
              )}
            </p>
            <div className="mt-1.5 flex flex-wrap justify-center gap-2.5">
              {pricing && pricing.signup_credits > 0 && (
                <Pill tone="success">{`${pricing.signup_credits} free trial credits`}</Pill>
              )}
              <Pill tone="info">{t("No payment to sign up")}</Pill>
              <Pill>{t("Prices in USD · paid with PayPal")}</Pill>
            </div>
            {rateLine && <p className="text-sm font-medium">{rateLine}</p>}
          </div>
        </section>

        <section className="mx-auto max-w-[1200px] px-6" aria-label={t("Credit packs")}>
          {state.kind === "error" ? (
            <div className="mx-auto max-w-3xl">
              <StateBanner
                tone="warning"
                title={t("Pricing could not be loaded")}
                body={t("Please refresh the page in a moment.")}
                action={
                  <Button size="sm" variant="outline" onClick={() => void query.refetch()}>
                    {t("Retry")}
                  </Button>
                }
              />
            </div>
          ) : state.kind === "loading" ? (
            <div className="grid gap-6 md:grid-cols-3">
              {[0, 1, 2].map((i) => (
                <div key={i} className="h-80 animate-pulse rounded-2xl border bg-muted" />
              ))}
            </div>
          ) : !packages.length ? (
            <EmptyState
              icon={CreditCard}
              title={t("Credit packages are not available right now")}
              body={t("Please check back soon.")}
            />
          ) : (
            <div className="grid items-stretch gap-6 md:grid-cols-3">
              {pricing!.packages.map((item, index) => {
                const hours = packHours(item);
                const perHour = packPricePerHour(item);
                const saving =
                  perHour !== null && basePerHour && perHour < basePerHour
                    ? Math.round((1 - perHour / basePerHour) * 100)
                    : 0;
                const isRecommended = index === recommended;
                const isBest = perHour !== null && perHour === bestPerHour && packages.length > 1;
                return (
                  <article
                    key={item.id}
                    className={cn(
                      "relative flex flex-col gap-5 rounded-2xl border bg-surface p-8 shadow-card",
                      isRecommended && "outline outline-2 -outline-offset-1 outline-primary",
                    )}
                  >
                    {isBest && (
                      <span className="absolute -top-3 left-8 inline-flex h-[26px] items-center rounded-full bg-primary px-3 text-xs font-bold text-primary-foreground shadow-glow">
                        {t("Best value")}
                      </span>
                    )}
                    <div className="flex items-center justify-between gap-2">
                      <h2 className="text-[21px] font-bold">{item.name}</h2>
                      {isRecommended && <Pill tone="success">{t("Fits your schedule")}</Pill>}
                    </div>
                    <div className="flex items-baseline gap-2">
                      <span className="text-[52px] font-extrabold tracking-[-.04em]">
                        {formatMoneyValue(item.price, language)}
                      </span>
                      <span className="text-muted-foreground">{t("One-time purchase")}</span>
                    </div>
                    <div className="flex items-center justify-between rounded-xl bg-surface-2 px-4 py-3.5">
                      <span className="text-lg font-bold">
                        {hours !== null
                          ? formatRecordingTime(Math.round(hours * 60))
                          : `${item.credits.toLocaleString(language)} credits`}
                      </span>
                      {perHour !== null && (
                        <span className="flex flex-col items-end gap-0.5">
                          <span className="font-mono font-bold text-accent-ink">
                            {formatPerHour(perHour, item.price.currency, language)} / hour
                          </span>
                          <span className="text-xs text-muted-foreground">
                            {saving > 0 ? `Save ${saving}% vs ${packages[0]!.name}` : "Base rate"}
                          </span>
                        </span>
                      )}
                    </div>
                    <p className="text-sm text-muted-foreground">
                      {item.credits.toLocaleString(language)} credits
                    </p>
                    <div className="mt-auto">
                      {channels.web ? (
                        <Button
                          size="lg"
                          className="w-full"
                          variant={isRecommended ? "default" : "outline"}
                          asChild
                        >
                          <Link to={ctaTo}>{t(authenticated ? "Buy credits" : "Get started")}</Link>
                        </Button>
                      ) : authenticated ? (
                        <Button size="lg" className="w-full" disabled>
                          {t("Coming soon")}
                        </Button>
                      ) : (
                        <Button size="lg" className="w-full" variant="outline" asChild>
                          <Link to="/sign-up">{t("Create free account")}</Link>
                        </Button>
                      )}
                    </div>
                  </article>
                );
              })}
            </div>
          )}
          {!channels.web && !channels.loading && packages.length ? (
            <p className="mx-auto mt-6 max-w-2xl text-center text-sm text-muted-foreground">
              {t("Online checkout is not open yet. Your free trial credits work as usual.")}
            </p>
          ) : null}
        </section>

        {recommendedPack && recommendedHours !== null && (
          <section className="mx-auto max-w-[1200px] px-6 pt-8" aria-label={t("Credit calculator")}>
            <div className="grid items-center gap-9 rounded-[20px] border bg-gradient-to-br from-surface to-surface-2 p-8 shadow-card md:grid-cols-2">
              <div className="flex flex-col gap-4">
                <label htmlFor="pricing-hours" className="text-[21px] font-bold">
                  {t("How many hours do you stream per week?")}
                </label>
                <div className="flex items-center gap-4">
                  <input
                    id="pricing-hours"
                    type="range"
                    min={1}
                    max={60}
                    step={1}
                    value={hoursPerWeek}
                    onChange={(event) => setHoursPerWeek(Number(event.target.value))}
                    className="h-7 w-full cursor-pointer accent-primary"
                  />
                  <span className="min-w-24 text-right font-mono text-[22px] font-semibold">
                    {hoursPerWeek} h/wk
                  </span>
                </div>
              </div>
              <div
                className="flex flex-col gap-2.5 rounded-2xl border bg-surface p-6"
                aria-live="polite"
              >
                <span className="text-sm font-bold text-muted-foreground">{t("We recommend")}</span>
                <div className="flex flex-wrap items-baseline gap-2.5">
                  <span className="text-[30px] font-extrabold tracking-[-.02em] text-accent-ink">
                    {recommendedPack.name}
                  </span>
                  <span className="font-bold">
                    {formatMoneyValue(recommendedPack.price, language)} ·{" "}
                    {formatRecordingTime(Math.round(recommendedHours * 60))}
                  </span>
                </div>
                <p className="text-muted-foreground">
                  About <b className="text-foreground">{Math.round(hoursPerWeek * 4.33)} h</b> of
                  LIVE a month — this pack lasts roughly{" "}
                  <b className="text-foreground">
                    {Math.max(1, Math.round(recommendedHours / hoursPerWeek))} weeks
                  </b>{" "}
                  at your pace. Leftover credits never expire.
                </p>
              </div>
            </div>
          </section>
        )}

        <section className="mx-auto grid max-w-[1200px] items-start gap-12 px-6 pt-24 lg:grid-cols-2">
          <div className="flex flex-col gap-3.5">
            <span className="text-xs font-bold uppercase tracking-[.08em] text-accent-ink">
              {t("Free trial")}
            </span>
            <h2 className="text-4xl font-extrabold tracking-[-.025em]">
              {t("Try it before you buy.")}
            </h2>
            <p className="text-lg leading-relaxed text-muted-foreground">
              {pricing && pricing.signup_credits > 0
                ? `New accounts get ${pricing.signup_credits} free credits after verifying their email. Automatic cloud recording unlocks with your first purchase.`
                : t(
                    "Create a free account to add channels. Automatic cloud recording unlocks with your first purchase.",
                  )}
            </p>
            {!authenticated && (
              <Button size="lg" className="mt-2 self-start" asChild>
                <Link to="/sign-up">{t("Create free account")}</Link>
              </Button>
            )}
          </div>
          <div className="overflow-x-auto rounded-2xl border bg-surface">
            <table className="w-full text-[15px]">
              <caption className="sr-only">{t("Free trial compared with paid packs")}</caption>
              <thead>
                <tr className="border-b text-left text-sm">
                  <th scope="col" className="px-4 py-3" />
                  <th scope="col" className="px-4 py-3 font-semibold">
                    {t("Free trial")}
                  </th>
                  <th scope="col" className="px-4 py-3 font-semibold text-accent-ink">
                    {t("Any paid pack")}
                  </th>
                </tr>
              </thead>
              <tbody>
                {comparison.map(([label, trial, paid]) => (
                  <tr key={label} className="border-b last:border-0">
                    <th scope="row" className="px-4 py-3.5 text-left font-semibold">
                      {t(label)}
                    </th>
                    <td className="px-4 py-3.5 text-muted-foreground">{t(trial)}</td>
                    <td className="px-4 py-3.5 font-medium">{t(paid)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="mx-auto max-w-[1200px] px-6 pt-12">
          <div className="grid gap-8 rounded-2xl border bg-surface p-6 shadow-card md:grid-cols-2">
            <div>
              <h2 className="font-bold">{t("Included with every package")}</h2>
              <ul className="mt-4 space-y-3 text-sm">
                {[...packageLimits(pricing, language), ...includedInEveryPackage.map(t)].map(
                  (line) => (
                    <li key={line} className="flex gap-2">
                      <Check className="mt-0.5 size-4 shrink-0 text-primary" />
                      <span>{line}</span>
                    </li>
                  ),
                )}
              </ul>
            </div>
            <div className="space-y-4 text-sm text-muted-foreground">
              <div>
                <h3 className="font-bold text-foreground">{t("How credits are used")}</h3>
                <p className="mt-1 leading-6">{creditUsageSentence(rate)}</p>
              </div>
              <div>
                <h3 className="font-bold text-foreground">{t("Payments and refunds")}</h3>
                <p className="mt-1 leading-6">
                  {t(
                    "Payments are processed by PayPal. Prices are shown in USD; applicable taxes are calculated at checkout. See our",
                  )}{" "}
                  <Link to="/refund" className="text-accent-ink underline underline-offset-4">
                    {t("refund policy")}
                  </Link>
                  .
                </p>
              </div>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-[860px] px-6 pt-24" aria-labelledby="payment-faq">
          <div className="mb-8 flex flex-col items-center gap-3 text-center">
            <span className="text-xs font-bold uppercase tracking-[.08em] text-accent-ink">
              {t("Payments")}
            </span>
            <h2 id="payment-faq" className="text-4xl font-extrabold tracking-[-.025em]">
              {t("Payment questions")}
            </h2>
          </div>
          <div className="flex flex-col gap-3">
            {paymentFaqs.map((faq, index) => {
              const open = openFaq === index;
              return (
                <div key={faq.q} className="rounded-2xl border bg-surface">
                  <button
                    type="button"
                    aria-expanded={open}
                    onClick={() => setOpenFaq(open ? -1 : index)}
                    className="flex min-h-16 w-full items-center justify-between gap-4 px-[22px] py-[18px] text-left text-[17px] font-semibold"
                  >
                    <span>{t(faq.q)}</span>
                    <ChevronDown
                      className={cn("size-5 flex-none transition-transform", open && "rotate-180")}
                    />
                  </button>
                  {open && (
                    <p className="px-[22px] pb-[22px] leading-relaxed text-muted-foreground">
                      {t(faq.a)}
                    </p>
                  )}
                </div>
              );
            })}
          </div>
        </section>
      </main>
      <PublicFooter />
    </>
  );
}

function creditUsageSentence(rate: PublicRecordingRate | null) {
  if (!rate || rate.credits_per_unit === 0) {
    return "Credits are used only while a livestream is being recorded. Monitoring a channel while it is offline is free.";
  }
  const unit =
    rate.unit_seconds % 60 === 0
      ? pluralize(rate.unit_seconds / 60, "minute")
      : pluralize(rate.unit_seconds, "second");
  const minimum =
    rate.minimum_credits > 0
      ? `, with a minimum of ${pluralize(rate.minimum_credits, "credit")} per recording`
      : "";
  return `Credits are used only while a livestream is being recorded, counted in blocks of ${unit} and rounded up${minimum}. Failed recordings are not charged, and monitoring a channel while it is offline is free.`;
}

function DemoPricingPage() {
  const { t, language } = usePreferences();
  return (
    <>
      <PublicHeader />
      <main className="mx-auto max-w-5xl px-4 pb-20 pt-32">
        <div className="text-center">
          <h1 className="text-4xl font-semibold">{t("Plans that scale with your livestreams.")}</h1>
          <p className="mt-4 text-muted-foreground">
            {t("Start free. Upgrade when you need more recording time.")}
          </p>
        </div>
        <div className="mt-12 grid gap-5 md:grid-cols-2">
          {planList.map((plan) => (
            <PlanCard
              key={plan.id}
              name={plan.name}
              price={
                plan.priceMonthlyUsd ? formatCurrencyUsd(plan.priceMonthlyUsd, language) : "Free"
              }
              features={[...plan.features]}
              action={
                <Button
                  variant={plan.id === "pro" ? "default" : "outline"}
                  className="mt-6 w-full"
                  asChild
                >
                  <Link to="/sign-up">
                    {t(plan.id === "pro" ? "Start with Pro" : "Start for free")}
                  </Link>
                </Button>
              }
            />
          ))}
        </div>
        <section className="mt-8 rounded-lg border bg-surface-subtle p-5">
          <h2 className="text-sm font-semibold">{t("Plan limits")}</h2>
          <dl className="mt-3 grid gap-4 sm:grid-cols-3">
            {planLimitDefinitions.map((item) => (
              <div key={item.key}>
                <dt className="text-sm font-medium">{t(item.label)}</dt>
                <dd className="mt-1 text-xs leading-5 text-muted-foreground">
                  {t(item.description)}
                </dd>
              </div>
            ))}
          </dl>
          <p className="mt-4 text-xs text-muted-foreground">{t(planMediaFootnote)}</p>
        </section>
      </main>
      <PublicFooter />
    </>
  );
}

export function PublicFooter() {
  const { t } = usePreferences();
  const cols: [string, [string, string][]][] = [
    [
      "Product",
      [
        ["/#features", "Features"],
        ["/#how", "How it works"],
        ["/#examples", "Examples"],
        ["/pricing", "Pricing"],
      ],
    ],
    [
      "Legal",
      [
        ["/terms", "Terms of Use"],
        ["/privacy", "Privacy Policy"],
        ["/acceptable-use", "Acceptable Use Policy"],
        ["/copyright", "Copyright & Takedown"],
        ["/refund", "Refund Policy"],
      ],
    ],
    [
      "Help",
      [
        ["/help", "Help center"],
        ["/#faq", "FAQ"],
        ["/contact", "Contact support"],
        ["/status", "System status"],
      ],
    ],
  ];
  return (
    <footer className="mt-24 border-t">
      <div className="mx-auto grid max-w-[1240px] gap-10 px-6 py-12 md:grid-cols-[1.5fr_repeat(3,1fr)]">
        <div>
          <Logo />
          <p className="mt-4 max-w-xs text-sm leading-6 text-muted-foreground">
            {t("Automatic cloud recording for TikTok LIVE.")}
          </p>
        </div>
        {cols.map(([h, links]) => (
          <nav key={h} aria-label={t(h)}>
            <p className="text-xs font-bold uppercase tracking-[.08em] text-muted-foreground">
              {t(h)}
            </p>
            <ul className="mt-3 space-y-2 text-[15px]">
              {links.map(([to, l]) => (
                <li key={to}>
                  {to.startsWith("/#") ? (
                    <a href={to} className="text-muted-foreground hover:text-foreground">
                      {t(l)}
                    </a>
                  ) : (
                    <Link
                      to={to as "/pricing"}
                      className="text-muted-foreground hover:text-foreground"
                    >
                      {t(l)}
                    </Link>
                  )}
                </li>
              ))}
            </ul>
          </nav>
        ))}
      </div>
      <div className="mx-auto flex max-w-[1240px] flex-wrap justify-between gap-3 border-t px-6 py-6 text-sm text-muted-foreground">
        <span>© 2026 SaveStream · savestream.online</span>
        <span>{t("SaveStream is not affiliated with TikTok.")}</span>
      </div>
    </footer>
  );
}
const channelStates = [
  { value: "Recording", label: "Recording" },
  { value: "Live", label: "Live" },
  { value: "Waiting", label: "Waiting" },
  { value: "Offline", label: "Offline" },
  { value: "Paused", label: "Paused" },
  { value: "Error", label: "Error" },
] as const;
function formatClock(totalSeconds: number) {
  const s = Math.max(0, Math.floor(totalSeconds));
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${Math.floor(s / 3600)}:${pad(Math.floor((s % 3600) / 60))}:${pad(s % 60)}`;
}

function formatShortDuration(totalSeconds: number) {
  const minutes = Math.round(totalSeconds / 60);
  if (minutes < 60) return `${minutes}m`;
  return `${Math.floor(minutes / 60)}h ${String(minutes % 60).padStart(2, "0")}m`;
}

/** Seconds recorded, ticking locally between the 5 s polls. */
function useElapsedSeconds(base: number | undefined, running: boolean) {
  const [since, setSince] = useState(() => Date.now());
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    setSince(Date.now());
    setNow(Date.now());
  }, [base]);
  useEffect(() => {
    if (!running) return;
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [running]);
  if (base === undefined) return undefined;
  return base + (running ? Math.max(0, (now - since) / 1000) : 0);
}

type ChannelBannerTone = "rec" | "warn" | "info" | "err";

function ChannelStatusBanner({
  tone,
  icon,
  title,
  description,
  detail,
  elapsed,
  actions,
}: {
  tone: ChannelBannerTone;
  icon: ReactNode;
  title: string;
  description: ReactNode;
  detail?: string | null;
  elapsed?: string | null;
  actions?: ReactNode;
}) {
  return (
    <section
      aria-label="Channel status"
      className={cn(
        "flex flex-col gap-4 rounded-[18px] border px-6 py-5 md:flex-row md:items-center",
        tone === "rec" && "border-recording/25 bg-recording-subtle",
        tone === "warn" && "border-warning/30 bg-warning-subtle",
        tone === "info" && "border-info/25 bg-info-subtle",
        tone === "err" && "border-destructive/30 bg-destructive/10",
      )}
    >
      <span
        aria-hidden="true"
        className={cn(
          "grid size-[52px] shrink-0 place-items-center rounded-[16px] bg-surface",
          tone === "rec" && "text-recording",
          tone === "warn" && "text-warning",
          tone === "info" && "text-info",
          tone === "err" && "text-destructive",
        )}
      >
        {icon}
      </span>
      <div className="min-w-0 flex-1 space-y-1">
        <b className="block text-lg">{title}</b>
        <p className="text-sm text-muted-foreground">{description}</p>
        {detail && (
          <code className="mt-1.5 block w-fit rounded-lg border bg-surface px-2.5 py-2 font-mono text-xs text-destructive">
            {detail}
          </code>
        )}
      </div>
      {elapsed && (
        <div className="flex flex-col md:items-end">
          <span className="text-xs text-muted-foreground">Elapsed</span>
          <span className="font-mono text-3xl font-semibold">{elapsed}</span>
        </div>
      )}
      {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
    </section>
  );
}

function ChannelHistoryAction({ recording }: { recording: RecordingModel }) {
  const label =
    recording.status === "Recording"
      ? "Watch live"
      : recording.status === "Ready"
        ? "Play"
        : recording.status === "Error" || recording.status === "Missed"
          ? "Why?"
          : "Details";
  return (
    <Button asChild variant="ghost" size="sm">
      <Link to="/recordings/$id" params={{ id: recording.id }}>
        {label}
      </Link>
    </Button>
  );
}

function ChannelDetail({
  channel,
  history,
  onRefresh,
}: {
  channel: ChannelModel;
  history: RecordingModel[];
  onRefresh: () => Promise<unknown>;
}) {
  const navigate = useNavigate();
  const pauseChannel = usePauseChannelMutation();
  const updateChannel = useUpdateChannelMutation();
  const stopRecording = useStopRecordingMutation();
  const { query: entitlementQuery } = useEntitlementData(!isDemoMode);
  const canAutoRecord = isDemoMode || entitlementQuery.data?.plan === "pro";
  const resumeChannel = useResumeChannelMutation();
  const deleteChannel = useDeleteChannelMutation();
  const [previewState, setPreviewState] = useState<ChannelStatus>(channel.status);
  const [dialog, setDialog] = useState<null | "pause" | "remove" | "stop">(null);
  const state = isDemoMode ? previewState : channel.status;
  const monitoring = isDemoMode ? state !== "Paused" : channel.backendStatus === "active";
  const pending =
    pauseChannel.isPending ||
    resumeChannel.isPending ||
    deleteChannel.isPending ||
    updateChannel.isPending;
  const activeRecording = channel.activeRecordingId
    ? history.find((recording) => recording.id === channel.activeRecordingId)
    : history.find((recording) => recording.status === "Recording");
  const elapsed = useElapsedSeconds(activeRecording?.durationSeconds, state === "Recording");
  const finished = history.filter((r) => r.status === "Ready" && (r.durationSeconds ?? 0) > 0);
  const averageSeconds = finished.length
    ? finished.reduce((sum, r) => sum + (r.durationSeconds ?? 0), 0) / finished.length
    : null;
  const creditsUsed = history.reduce((sum, r) => sum + (r.creditsUsed ?? 0), 0);
  const tiktokUrl = `https://www.tiktok.com/${channel.handle}`;

  const setAutoRecord = async (value: boolean) => {
    try {
      await updateChannel.mutateAsync({ id: channel.id, input: { auto_record: value } });
      toast.success(
        value
          ? `Automatic recording turned on for ${channel.handle}`
          : `Automatic recording turned off for ${channel.handle}`,
      );
    } catch (error) {
      toast.error("Could not change automatic recording", {
        description: channelActionErrorMessage(error),
      });
    }
  };

  useEffect(() => {
    setPreviewState(channel.status);
  }, [channel.status]);

  const resume = async () => {
    try {
      await resumeChannel.mutateAsync(channel.id);
      if (isDemoMode) setPreviewState("Waiting");
      toast.success(`Monitoring resumed for ${channel.handle}`);
    } catch (error) {
      toast.error("Could not resume monitoring", {
        description: channelActionErrorMessage(error),
      });
    }
  };

  const toggle = (value: boolean) => {
    if (pending) return;
    if (value) {
      void resume();
    } else {
      setDialog("pause");
    }
  };

  const live = state === "Recording" || state === "Live";
  const badges: Status[] =
    state === "Recording" ? ["Recording"] : state === "Live" ? ["Live"] : [state];

  let banner: ReactNode;
  if (state === "Recording") {
    banner = (
      <ChannelStatusBanner
        tone="rec"
        icon={<Radio className="size-6" />}
        title="LIVE — recording"
        description="Recording on our servers. You can safely close this page — we’ll email you when it’s ready."
        elapsed={elapsed !== undefined ? formatClock(elapsed) : null}
        actions={
          <>
            {activeRecording?.actions.can_stop && (
              <Button variant="outline" onClick={() => setDialog("stop")}>
                Stop recording
              </Button>
            )}
            <Button asChild>
              {channel.activeRecordingId ? (
                <Link to="/recordings/$id" params={{ id: channel.activeRecordingId }}>
                  View recording
                </Link>
              ) : (
                <Link to="/recordings/active">View recording</Link>
              )}
            </Button>
          </>
        }
      />
    );
  } else if (state === "Live") {
    const reason = channel.autoRecordState;
    if (reason === "paused_no_cloud_minutes" || (!canAutoRecord && channel.autoRecord)) {
      banner = (
        <ChannelStatusBanner
          tone="warn"
          icon={<CreditCard className="size-6" />}
          title="LIVE — not recording: out of credits"
          description={
            canAutoRecord
              ? "No recording was started because your balance is empty. Add credits and recording starts at the next check — while the channel is still live."
              : "Automatic recording unlocks after you buy credits. Buy any pack and turn on Auto-record for this channel."
          }
          actions={
            <Button asChild>
              <Link to="/billing">Buy credits</Link>
            </Button>
          }
        />
      );
    } else if (reason === "waiting_for_cloud_slot") {
      banner = (
        <ChannelStatusBanner
          tone="warn"
          icon={<AlertTriangle className="size-6" />}
          title="LIVE — not recording yet: no recorder slot available"
          description="All recorders are busy right now. We retry automatically, and no credits are used until a recording starts."
          actions={
            <Button asChild variant="outline">
              <Link to="/status">Check status</Link>
            </Button>
          }
        />
      );
    } else if (reason === "active") {
      banner = (
        <ChannelStatusBanner
          tone="rec"
          icon={<Radio className="size-6" />}
          title="LIVE — starting the recording…"
          description="We detected the LIVE and are starting a recording on our servers. This usually takes under a minute."
        />
      );
    } else {
      banner = (
        <ChannelStatusBanner
          tone="warn"
          icon={<AlertTriangle className="size-6" />}
          title="LIVE — not recording: auto-record is off"
          description="We detected the LIVE but didn’t start a recording because auto-record is off for this channel."
          actions={
            <>
              <Button asChild variant="outline">
                <a href={`${tiktokUrl}/live`} target="_blank" rel="noopener noreferrer">
                  Watch on TikTok
                </a>
              </Button>
              {canAutoRecord && (
                <Button disabled={pending} onClick={() => void setAutoRecord(true)}>
                  Turn on auto-record
                </Button>
              )}
            </>
          }
        />
      );
    }
  } else if (state === "Paused") {
    banner = (
      <ChannelStatusBanner
        tone="warn"
        icon={<Pause className="size-6" />}
        title="Monitoring is paused"
        description="We aren’t checking this channel, so new LIVEs won’t be recorded. Existing recordings aren’t affected."
        actions={
          <Button disabled={pending} onClick={() => void resume()}>
            Resume monitoring
          </Button>
        }
      />
    );
  } else if (state === "Error") {
    banner = (
      <ChannelStatusBanner
        tone="err"
        icon={<AlertCircle className="size-6" />}
        title="We can’t reach this channel"
        description="The last checks failed. The username may have changed, or the account is private or restricted. We keep retrying automatically."
        actions={
          <>
            <Button asChild variant="outline">
              <a href={tiktokUrl} target="_blank" rel="noopener noreferrer">
                Open on TikTok
              </a>
            </Button>
            <Button
              onClick={() => {
                toast("Refreshing channel status…");
                void onRefresh();
              }}
            >
              Refresh status
            </Button>
          </>
        }
      />
    );
  } else {
    banner = (
      <ChannelStatusBanner
        tone="info"
        icon={<Clock3 className="size-6" />}
        title={
          state === "Offline" ? "Offline — watching for the next LIVE" : "Waiting for the next LIVE"
        }
        description={`Last checked ${channel.checked}. Last LIVE ${channel.live}. ${
          channel.autoRecord && canAutoRecord
            ? "Recording starts automatically when the channel goes live."
            : "Auto-record is off, so LIVEs are detected but not recorded."
        } Monitoring is free.`}
        actions={
          <Button variant="outline" disabled={pending} onClick={() => setDialog("pause")}>
            Pause monitoring
          </Button>
        }
      />
    );
  }

  return (
    <AppShell>
      <div className="flex flex-col gap-6">
        <Link
          to="/channels"
          className="inline-flex w-fit items-center gap-1 text-sm font-bold text-accent-ink hover:underline"
        >
          <ArrowLeft className="size-4" />
          All channels
        </Link>
        {isDemoMode && (
          <PrototypeStateBar
            label="Preview channel state"
            value={previewState}
            options={channelStates}
            onChange={setPreviewState}
          />
        )}
        <header className="flex flex-wrap items-center gap-5 rounded-[20px] border bg-surface p-6 md:p-7">
          <div
            className={cn(
              "rounded-full",
              live && "ring-[3px] ring-recording ring-offset-[3px] ring-offset-surface",
            )}
          >
            <CreatorAvatar channel={channel} size="xl" />
          </div>
          <div className="min-w-0 flex-[1_1_280px] space-y-1.5">
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="truncate text-[28px] font-extrabold tracking-tight">
                {channel.handle}
              </h1>
              {live && (
                <span className="inline-flex h-6 items-center gap-1.5 rounded-full bg-recording px-2.5 text-xs font-bold text-white">
                  <span className="size-1.5 animate-pulse rounded-full bg-white" />
                  LIVE
                </span>
              )}
              {badges.map((badge) => (
                <StatusBadge key={badge} status={badge} pulse={badge === "Recording"} />
              ))}
            </div>
            <p className="text-sm text-muted-foreground">
              {channel.name} ·{" "}
              <a
                href={tiktokUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="font-semibold text-accent-ink hover:underline"
              >
                View on TikTok ↗
              </a>
            </p>
          </div>
          <div className="flex flex-col gap-2.5">
            <label className="flex items-center gap-2.5 text-sm font-bold">
              <Switch
                checked={monitoring}
                disabled={pending}
                onCheckedChange={toggle}
                aria-label="Monitoring"
              />
              <span className="min-w-[120px]">Monitoring {monitoring ? "on" : "paused"}</span>
            </label>
            <label
              className="flex items-center gap-2.5 text-sm font-bold"
              title={
                canAutoRecord ? undefined : "Automatic recording unlocks after you buy credits"
              }
            >
              <Switch
                checked={channel.autoRecord && canAutoRecord}
                disabled={pending || !canAutoRecord}
                onCheckedChange={(value) => void setAutoRecord(value)}
                aria-label="Auto-record"
              />
              <span className="min-w-[120px]">
                Auto-record {channel.autoRecord && canAutoRecord ? "on" : "off"}
              </span>
            </label>
          </div>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="icon" aria-label="More channel actions">
                <MoreHorizontal />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onSelect={() => window.open(tiktokUrl, "_blank", "noopener")}>
                <ExternalLink />
                Open on TikTok
              </DropdownMenuItem>
              {monitoring ? (
                <DropdownMenuItem onSelect={() => setDialog("pause")}>
                  <Pause />
                  Pause monitoring
                </DropdownMenuItem>
              ) : (
                <DropdownMenuItem onSelect={() => void resume()}>
                  <Radio />
                  Resume monitoring
                </DropdownMenuItem>
              )}
              <DropdownMenuSeparator />
              <DropdownMenuItem className="text-destructive" onSelect={() => setDialog("remove")}>
                <Trash2 />
                Remove channel
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </header>

        {banner}

        <div className="grid gap-4 [grid-template-columns:repeat(auto-fit,minmax(min(200px,100%),1fr))]">
          {[
            { label: "Recordings", value: String(channel.recordings), note: "in your library" },
            {
              label: "Hours recorded",
              value: channel.recordedHours,
              note:
                creditsUsed > 0
                  ? `${creditsUsed.toLocaleString("en")} credits used`
                  : "all recordings",
            },
            {
              label: "Average LIVE",
              value: averageSeconds ? formatShortDuration(averageSeconds) : "—",
              note: finished.length
                ? `across ${pluralize(finished.length, "recording")}`
                : "no finished recordings yet",
            },
            {
              label: "Storage used",
              value: channel.storage,
              note: `${pluralize(history.length, "file")}`,
            },
          ].map((kpi) => (
            <div
              key={kpi.label}
              className="flex flex-col gap-1 rounded-[16px] border bg-surface p-5"
            >
              <span className="text-sm font-semibold text-muted-foreground">{kpi.label}</span>
              <span className="font-mono text-[28px] font-semibold leading-tight">{kpi.value}</span>
              <span className="text-xs text-muted-foreground">{kpi.note}</span>
            </div>
          ))}
        </div>

        <section aria-labelledby="channel-history" className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <h2 id="channel-history" className="text-[17px] font-bold">
              Recording history
            </h2>
            <Link to="/recordings" className="text-sm font-bold text-accent-ink hover:underline">
              Open in library →
            </Link>
          </div>
          {history.length ? (
            <>
              <div className="hidden overflow-x-auto rounded-[16px] border bg-surface md:block">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b bg-surface-2 text-left text-[11px] font-bold uppercase tracking-[.06em] text-muted-foreground">
                      <th scope="col" className="px-4 py-3">
                        Recording
                      </th>
                      <th scope="col" className="px-4 py-3">
                        Started
                      </th>
                      <th scope="col" className="px-4 py-3">
                        Duration
                      </th>
                      <th scope="col" className="px-4 py-3">
                        Status
                      </th>
                      <th scope="col" className="px-4 py-3 text-right">
                        Credits
                      </th>
                      <th scope="col" className="px-4 py-3">
                        Expires
                      </th>
                      <th scope="col" className="px-4 py-3">
                        <span className="sr-only">Actions</span>
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {history.map((recording) => (
                      <tr key={recording.id} className="border-b last:border-b-0">
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-3">
                            <span
                              aria-hidden="true"
                              className={cn("h-14 w-8 shrink-0 rounded-md", recording.color)}
                            />
                            <b className="font-semibold">{recording.title}</b>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-muted-foreground">
                          {recording.date}, {recording.time}
                        </td>
                        <td className="px-4 py-3 font-mono">
                          {recording.status === "Recording" ? "In progress" : recording.duration}
                        </td>
                        <td className="px-4 py-3">
                          <StatusBadge status={recording.status} />
                        </td>
                        <td className="px-4 py-3 text-right font-mono">
                          {recording.creditsUsed ?? "—"}
                        </td>
                        <td className="px-4 py-3 text-muted-foreground">
                          {recording.status === "Ready" ? recording.expires : "—"}
                        </td>
                        <td className="px-4 py-3 text-right">
                          <ChannelHistoryAction recording={recording} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className="grid gap-3 md:hidden">
                {history.map((recording) => (
                  <RecordingCard key={recording.id} recording={recording} />
                ))}
              </div>
            </>
          ) : (
            <EmptyState
              title="No recordings yet"
              body="The next LIVE from this channel will appear here automatically."
            />
          )}
        </section>
      </div>
      <ConfirmDialog
        open={dialog === "stop"}
        onOpenChange={(open) => !open && setDialog(null)}
        title="Stop this recording?"
        body="We’ll stop recording now and process what was captured so far. Credits are charged only for the time recorded."
        confirmLabel="Stop recording"
        destructive
        confirmDisabled={stopRecording.isPending}
        onConfirm={() => {
          if (!activeRecording) return;
          void stopRecording
            .mutateAsync(activeRecording.id)
            .then(() => {
              setDialog(null);
              toast.success("Stopping the recording…");
            })
            .catch((error) => {
              toast.error("Could not stop the recording", {
                description: channelActionErrorMessage(error),
              });
            });
        }}
      />
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
              if (isDemoMode) setPreviewState("Paused");
              setDialog(null);
              toast(`Monitoring paused for ${channel.handle}`);
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
              setDialog(null);
              toast.success(`${channel.handle} removed`);
              void navigate({ to: "/channels" });
            })
            .catch((error) => {
              toast.error("Could not remove channel", {
                description: channelActionErrorMessage(error),
              });
            });
        }}
      />
    </AppShell>
  );
}
function RecordingHeader() {
  const { t } = usePreferences();
  return (
    <div className="grid grid-cols-[1.7fr_1fr_.7fr_.7fr_.8fr_.7fr_auto] gap-4 border-b bg-surface-subtle px-4 py-2 text-[11px] font-medium uppercase text-muted-foreground">
      <span>{t("Recording")}</span>
      <span>{t("Streamer")}</span>
      <span>{t("Duration")}</span>
      <span>{t("Size")}</span>
      <span>{t("Expires")}</span>
      <span>{t("Status")}</span>
      <span className="w-9" />
    </div>
  );
}
const libraryStates = [
  { value: "populated", label: "Populated" },
  { value: "loading", label: "Loading" },
  { value: "empty", label: "Empty library" },
  { value: "error", label: "API retrying" },
] as const;
const usageStates = [
  { value: "normal", label: "Normal" },
  { value: "warning", label: "80% warning" },
  { value: "reached", label: "Quota reached" },
  { value: "download", label: "Downloads exhausted" },
  { value: "channels", label: "Channel limit" },
] as const;
