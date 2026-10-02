import { Link, useNavigate, useParams } from "@tanstack/react-router";
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
  AlertTriangle,
  ArrowLeft,
  ArrowRight,
  ArrowUpDown,
  RotateCcw,
  ExternalLink,
  Bell,
  Calendar,
  Check,
  CheckCircle2,
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
import {
  dailyRecordingHours,
  invoices,
  subscription,
  usage,
  user,
} from "@/mocks/fixtures";
import {
  ActiveRecordingCard,
  AddChannelDialog,
  AdminHealthBadge,
  AppShell,
  ChannelCard,
  ChannelRow,
  ConfirmDeleteDialog,
  ConfirmDialog,
  CreatorAvatar,
  EmptyState,
  ErrorState,
  FilterBar,
  LanguageMenu,
  Logo,
  PageHeader,
  PasswordField,
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
import { cn } from "@/lib/utils";
import { usePreferences } from "@/lib/preferences";
import { sampleMedia, type SampleMediaItem } from "@/lib/sample-media";
import { planCatalog, planList, planLimitDefinitions, planMediaFootnote } from "@/lib/plan-catalog";
import { formatCurrencyUsd, formatDate } from "@/lib/formatters";
import { billingCheckoutEnabled, isDemoMode } from "@/lib/app-config";
import { authApi, authErrorMessage } from "@/api/auth";
import type {
  CreditPackageResponse,
  CreditReservationResponse,
  CreditTransactionResponse,
  Money,
  PaymentOrderResponse,
  PaymentStatusValue,
  PricingResponse,
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
  usePaymentOrdersData,
  usePricingData,
  useRecordingArtifactsData,
  useRecordingData,
  useRecordingsData,
  useUsageData,
} from "@/hooks/use-domain-data";
import {
  channelActionErrorMessage,
  existingWatchId,
  useCreateChannelMutation,
  useDeleteChannelMutation,
  usePauseChannelMutation,
  useResumeChannelMutation,
} from "@/hooks/use-channel-mutations";
import type {
  ChannelModel,
  ChannelStatus,
  RecordingModel,
} from "@/repositories";
import {
  displayNameFromTikTokUsername,
  parseTikTokSource,
} from "@/lib/tiktok-source";
import {
  artifactActionErrorMessage,
  recordingActionErrorMessage,
  useDeleteRecordingMutation,
  useRecordingDownloadMutation,
  useStopRecordingMutation,
} from "@/hooks/use-recording-mutations";
import {
  useRecordingRealtime,
  type RecordingRealtimeState,
} from "@/hooks/use-recording-realtime";
import { useAdminOperationalSnapshotData } from "@/hooks/use-admin-data";
import {
  billingActionErrorMessage,
  isAwaitingPaymentConfirmation,
  useBillingCheckoutMutation,
  type BillingCheckoutInput,
} from "@/hooks/use-billing";

export { meta, publicMeta } from "@/components/app-components";

const publicLinks = [
  { href: "/#features", label: "Features" },
  { href: "/#how", label: "How it works" },
  { href: "/#examples", label: "Examples" },
  { to: "/pricing", label: "Pricing" },
  { href: "/#faq", label: "FAQ" },
] as const;
export function PublicHeader() {
  const { t } = usePreferences();
  return (
    <header className="fixed inset-x-0 top-0 z-[var(--z-sticky)] border-b bg-background/90 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-7xl items-center gap-2 px-4 sm:px-6">
        <Logo />
        <nav className="ml-8 hidden items-center gap-5 text-sm text-muted-foreground lg:flex">
          {publicLinks.map((link) =>
            "to" in link ? (
              <Link key={link.label} to={link.to}>
                {t(link.label)}
              </Link>
            ) : (
              <a key={link.label} href={link.href}>
                {t(link.label)}
              </a>
            ),
          )}
        </nav>
        <div className="ml-auto flex min-w-0 items-center gap-0.5 sm:gap-1">
          <LanguageMenu />
          <ThemeMenu />
          <Button variant="ghost" asChild className="hidden md:inline-flex">
            <Link to="/sign-in">{t("Sign in")}</Link>
          </Button>
          <Button asChild className="hidden md:inline-flex">
            <Link to="/sign-up">{t("Sign up")}</Link>
          </Button>
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
                <Button variant="outline" asChild>
                  <Link to="/sign-in">{t("Sign in")}</Link>
                </Button>
                <Button asChild>
                  <Link to="/sign-up">{t("Sign up")}</Link>
                </Button>
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
  return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m ${remaining}s`;
}

function RecordingExamples() {
  const { t } = usePreferences();
  const [selected, setSelected] = useState<SampleMediaItem | null>(null);

  return (
    <section id="examples" className="scroll-mt-16 border-b bg-surface-subtle py-20">
      <div className="mx-auto max-w-6xl px-4">
        <div className="max-w-xl">
          <p className="text-sm font-semibold text-primary">{t("Completed recordings")}</p>
          <h2 className="mt-2 text-3xl font-semibold">{t("Recording Examples")}</h2>
          <p className="mt-3 text-muted-foreground">
            {t("See what a completed cloud recording looks like. These are preserved SaveStream sample videos.")}
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
                  {formatSampleDuration(item.durationSeconds)}
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
                  <span className="font-mono">{item.width}×{item.height}</span>
                  <span className="font-mono">{formatSampleDuration(item.durationSeconds)}</span>
                </div>
              </div>
            </button>
          ))}
        </div>

        <div className="mt-10 text-center">
          <Button size="lg" asChild>
            <Link to="/sign-up">
              {t("Start recording your own livestreams")}
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
                {t("Demo preview")}
              </span>
              <StatusBadge status="Ready" />
            </div>
            <DialogTitle>{selected?.title}</DialogTitle>
            <DialogDescription>
              {t("Preserved sample media from the previous SaveStream frontend.")}
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
              [t("Resolution"), selected ? `${selected.width}×${selected.height}` : "—"],
              [t("Duration"), formatSampleDuration(selected?.durationSeconds)],
              ["ID", selected?.id ?? "—"],
            ].map(([label, value]) => (
              <div key={label} className="bg-surface p-3">
                <p className="text-xs text-muted-foreground">{label}</p>
                <p className="mt-1 font-mono font-medium">{value}</p>
              </div>
            ))}
          </div>

          <DialogFooter>
            <Button asChild>
              <Link to="/sign-up">{t("Start recording your own")}</Link>
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </section>
  );
}

export function LandingPage() {
  const { t, language } = usePreferences();
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "SaveStream",
    applicationCategory: "MultimediaApplication",
    operatingSystem: "Web",
    url: PUBLIC_SITE_URL,
    description: "Frontend preview for authorized livestream recording workflows.",
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
                  : "SaveStream monitors authorized TikTok channels and records livestreams on backend infrastructure, so recording does not depend on keeping this browser open.",
              )}
            </p>
            <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
              <Button size="lg" asChild>
                <Link to="/sign-up">
                  {t("Start for free")}
                  <ArrowRight />
                </Link>
              </Button>
              <Button size="lg" variant="outline" asChild>
                <a href="#how">{t("See how it works")}</a>
              </Button>
            </div>
            <p className="mt-3 text-xs text-muted-foreground">{t("No credit card required.")}</p>
            <div className="relative mx-auto mt-16 max-w-6xl overflow-hidden rounded-xl border bg-surface p-2 shadow-dashboard">
              <div className="flex h-10 items-center gap-2 border-b px-3">
                <span className="size-2.5 rounded-full bg-border" />
                <span className="size-2.5 rounded-full bg-border" />
                <span className="size-2.5 rounded-full bg-border" />
                <span className="mx-auto rounded border bg-background px-20 py-1 text-[9px] text-muted-foreground">
                  app.savestream.app/overview
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
                        {x}
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
                          label="Cloud monitoring"
                          value="Backend"
                          detail="Runs independently of this browser"
                          icon={Radio}
                        />
                        <StatCard
                          label="Recording charges"
                          value="Credits"
                          detail="Reserved and settled by the backend"
                          icon={CreditCard}
                        />
                        <StatCard
                          label="Recording library"
                          value="Synced"
                          detail="Authoritative account data"
                          icon={FileVideo}
                        />
                      </>
                    )}
                  </div>
                  <div className="mt-5">
                    <ActiveRecordingCard />
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
                [Radio, "We monitor it", "Backend monitoring is designed to check live status automatically."],
                [Video, "Recording starts", "Recording workers are designed to start automatically when backend services are connected."],
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
                {t("Production monitoring and recording are designed to run on backend services rather than in your browser.")}
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
                "Usage tracking",
                "Retention cleanup",
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
                      price={plan.priceMonthlyUsd === 0 ? "Free" : formatCurrencyUsd(plan.priceMonthlyUsd, language)}
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
                <h2 className="text-3xl font-semibold">{t("Credit-based pricing.")}</h2>
                <p className="mx-auto mt-4 max-w-2xl text-sm leading-6 text-muted-foreground">
                  {t("Production uses backend-authoritative credits instead of the old Free/Pro monthly quota model.")}
                </p>
                <div className="mt-10 grid gap-5 text-left md:grid-cols-3">
                  {[
                    ["Posted balance", "Credits added to your account are recorded in the backend ledger."],
                    ["Reservations", "Active recordings reserve credits before final usage is known."],
                    ["Settlement", "Final charges and unused-credit releases are settled by the backend."],
                  ].map(([title, body]) => (
                    <section key={title} className="rounded-lg border bg-surface p-5">
                      <h3 className="font-medium">{t(title)}</h3>
                      <p className="mt-2 text-sm leading-6 text-muted-foreground">{t(body)}</p>
                    </section>
                  ))}
                </div>
                <Button className="mt-8" variant="outline" asChild>
                  <Link to="/pricing">{t("View current pricing")}</Link>
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
                    "No. Monitoring and recording run on SaveStream backend services rather than in your browser.",
                  ],
                  [
                    "Which channels can I add?",
                    "Only TikTok channels you own, manage, or have explicit permission to record and archive.",
                  ],
                  [
                    "How are recording charges handled?",
                    "Production uses backend-authoritative credits. Credits may be reserved for an active recording and are settled when usage is known.",
                  ],
                  [
                    "How long are recordings kept?",
                    "Retention is controlled by the backend service policy. The production web app does not invent plan-specific retention periods.",
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
  const { signIn } = useAuth();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [pw, setPw] = useState("");
  const [pw2, setPw2] = useState("");
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const copy = {
    "sign-in": ["Welcome back", "Sign in to manage your recordings.", "Sign in"],
    "sign-up": [
      "Create your account",
      "Start monitoring your first TikTok channel.",
      "Create account",
    ],
    forgot: [
      "Reset your password",
      "Enter your email and we’ll send you a reset link.",
      "Send reset link",
    ],
    reset: ["Choose a new password", "Use at least 8 characters.", "Reset password"],
  }[mode];
  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setErr(null);
    if (mode !== "reset" && !/^\S+@\S+\.\S+$/.test(email)) {
      setErr("Enter a valid email address.");
      return;
    }
    if (mode === "sign-in" && !pw) {
      setErr("Enter your password.");
      return;
    }
    if ((mode === "sign-up" || mode === "reset") && pw.length < 8) {
      setErr("Password must be at least 8 characters.");
      return;
    }
    if (mode === "reset" && pw !== pw2) {
      setErr("Passwords don’t match.");
      return;
    }
    if (mode === "reset" && !token) {
      setErr("This password reset link is missing or invalid.");
      return;
    }

    setBusy(true);

    if (isDemoMode) {
      setTimeout(() => {
        setBusy(false);
        if (mode === "sign-in") void navigate({ to: "/overview" });
        else if (mode === "sign-up") void navigate({ to: "/verify-email", search: { token: "" } });
        else setDone(true);
      }, 700);
      return;
    }

    try {
      if (mode === "sign-in") {
        await signIn(email, pw);
        await navigate({ to: "/overview" });
      } else if (mode === "sign-up") {
        await authApi.register({
          email,
          password: pw,
          display_name: name.trim() || null,
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
      setErr(authErrorMessage(error));
    } finally {
      setBusy(false);
    }
  };
  if (done && mode === "forgot")
    return (
      <AuthLayout>
        <span className="grid size-11 place-items-center rounded-full bg-primary-subtle text-primary">
          <Mail className="size-5" />
        </span>
        <h1 className="mt-6 text-2xl font-semibold">{t("Check your email")}</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          If an account exists for <b className="font-medium text-foreground">{email}</b>, we sent a
          password reset link. It expires in 60 minutes.
        </p>
        <div className="mt-8 space-y-2">
          <Button
            variant="outline"
            className="w-full"
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
            Resend link
          </Button>
          <Button variant="ghost" className="w-full" asChild>
            <Link to="/sign-in">{t("Back to sign in")}</Link>
          </Button>
        </div>
        {isDemoMode && (
          <p className="mt-6 text-xs text-muted-foreground">
            Prototype:{" "}
            <Link to="/reset-password" search={{ token: "" }} className="text-primary underline underline-offset-4">
              open the reset link
            </Link>
          </p>
        )}
      </AuthLayout>
    );
  if (done && mode === "reset")
    return (
      <AuthLayout>
        <SuccessState
          title="Password updated"
          body="Your password has been changed. Other sessions were signed out for your security."
          action={
            <Button asChild className="w-full">
              <Link to="/sign-in">{t("Back to sign in")}</Link>
            </Button>
          }
        />
      </AuthLayout>
    );
  return (
    <AuthLayout>
      <h1 className="text-2xl font-semibold">{copy[0]}</h1>
      <p className="mt-2 text-sm text-muted-foreground">{copy[1]}</p>
      {(mode === "sign-in" || mode === "sign-up") && (
        <>
          <Button
            variant="outline"
            className="mt-8 w-full"
            onClick={() => toast("Google sign-in isn’t connected in this prototype.")}
          >
            <span className="font-bold">G</span>Continue with Google
          </Button>
          <div className="my-5 flex items-center gap-3 text-xs text-muted-foreground">
            <span className="h-px flex-1 bg-border" />
            or continue with email
            <span className="h-px flex-1 bg-border" />
          </div>
        </>
      )}
      <form
        className={cn("space-y-4", (mode === "forgot" || mode === "reset") && "mt-8")}
        onSubmit={submit}
        noValidate
      >
        {mode === "sign-up" && (
          <Field
            label="Full name"
            placeholder="Alex Nguyen"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoComplete="name"
          />
        )}
        {mode !== "reset" && (
          <Field
            label="Email"
            placeholder="you@company.com"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
          />
        )}
        {mode === "sign-in" && (
          <Field
            label="Password"
            placeholder="••••••••"
            type="password"
            value={pw}
            onChange={(e) => setPw(e.target.value)}
            autoComplete="current-password"
          />
        )}
        {(mode === "sign-up" || mode === "reset") && (
          <PasswordField
            id="pw"
            label={mode === "reset" ? "New password" : "Password"}
            value={pw}
            onChange={setPw}
            showStrength
          />
        )}
        {mode === "reset" && (
          <PasswordField id="pw2" label="Confirm password" value={pw2} onChange={setPw2} />
        )}
        {mode === "sign-in" && (
          <div className="text-right">
            <Link to="/forgot-password" className="text-xs font-medium text-primary">
              Forgot password?
            </Link>
          </div>
        )}
        {err && (
          <p role="alert" className="text-sm text-destructive">
            {err}
          </p>
        )}
        <Button className="w-full" type="submit" disabled={busy}>
          {busy && (
            <span className="size-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
          )}
          {copy[2]}
        </Button>
        {mode === "sign-up" && (
          <p className="text-xs leading-5 text-muted-foreground">
            By creating an account you agree to the{" "}
            <Link to="/terms" className="underline underline-offset-4">
              Terms
            </Link>
            ,{" "}
            <Link to="/privacy" className="underline underline-offset-4">
              Privacy Policy
            </Link>
            , and{" "}
            <Link to="/acceptable-use" className="underline underline-offset-4">
              Acceptable Use Policy
            </Link>
            .
          </p>
        )}
      </form>
      <p className="mt-6 text-center text-sm text-muted-foreground">
        {mode === "sign-in" ? (
          <>
            New to SaveStream?{" "}
            <Link to="/sign-up" className="font-medium text-primary">
              Create account
            </Link>
          </>
        ) : mode === "sign-up" ? (
          <>
            Already have an account?{" "}
            <Link to="/sign-in" className="font-medium text-primary">
              Sign in
            </Link>
          </>
        ) : (
          <Link to="/sign-in" className="font-medium text-primary">
            Back to sign in
          </Link>
        )}
      </p>
    </AuthLayout>
  );
}
function Field({ label, id, ...props }: { label: string } & ComponentProps<typeof Input>) {
  const fid = id ?? label.toLowerCase().replace(/\s+/g, "-");
  return (
    <div>
      <label htmlFor={fid} className="block text-sm font-medium">
        {label}
      </label>
      <Input id={fid} className="mt-2" {...props} />
    </div>
  );
}
export function OnboardingPage() {
  const { t } = usePreferences();
  const createChannel = useCreateChannelMutation();
  const [step, setStep] = useState(1);
  const [username, setUsername] = useState("");
  const [createdHandle, setCreatedHandle] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const parsed = parseTikTokSource(username);
  const valid = Boolean(parsed);
  const displayName = parsed ? displayNameFromTikTokUsername(parsed.username) : "";

  const addChannel = async () => {
    if (!parsed || createChannel.isPending) return;
    setError(null);
    try {
      await createChannel.mutateAsync({
        source: parsed.source,
        auto_record: true,
      });
      setCreatedHandle(parsed.handle);
      setStep(3);
    } catch (createError) {
      const duplicateId = existingWatchId(createError);
      if (duplicateId) {
        setCreatedHandle(parsed.handle);
        setStep(3);
        return;
      }
      setError(channelActionErrorMessage(createError));
    }
  };

  return (
    <div className="min-h-screen bg-surface-subtle">
      <header className="border-b bg-background p-5">
        <div className="mx-auto max-w-3xl">
          <Logo />
        </div>
      </header>
      <main className="mx-auto max-w-2xl px-4 py-12">
        <div className="mb-8 flex items-center gap-2">
          {[1, 2, 3].map((number) => (
            <span
              key={number}
              className={cn(
                "h-1 flex-1 rounded-full",
                number <= step ? "bg-primary" : "bg-border",
              )}
            />
          ))}
        </div>
        <div className="rounded-lg border bg-background p-6 sm:p-10">
          {step === 1 && (
            <>
              <span className="grid size-11 place-items-center rounded-full bg-primary-subtle text-primary">
                <Radio />
              </span>
              <h1 className="mt-6 text-2xl font-semibold">
                {t("Let’s record your first livestream.")}
              </h1>
              <p className="mt-2 text-muted-foreground">
                Add a TikTok channel and we’ll monitor it automatically.
              </p>
              <Button className="mt-8" onClick={() => setStep(2)}>
                Add my first channel
                <ArrowRight />
              </Button>
            </>
          )}
          {step === 2 && (
            <>
              <h1 className="text-2xl font-semibold">Add a channel</h1>
              <p className="mt-2 text-sm text-muted-foreground">
                Enter a TikTok username or profile URL.
              </p>
              <div className="mt-8 grid grid-cols-2 gap-3">
                <div className="rounded-lg border border-primary bg-primary-subtle p-4">
                  <PlatformBadge />
                  <p className="mt-3 text-sm font-medium">{t("Available")}</p>
                </div>
                <div className="rounded-lg border p-4 opacity-60">
                  <PlatformBadge soon />
                  <p className="mt-3 text-sm">{t("Coming soon")}</p>
                </div>
              </div>
              <div className="mt-6">
                <Field
                  label="TikTok username or URL"
                  placeholder="@mikefitness"
                  value={username}
                  onChange={(event) => {
                    setUsername(event.target.value);
                    setError(null);
                  }}
                  aria-invalid={Boolean(username) && !valid}
                />
                {username && !valid && (
                  <p className="mt-2 text-xs text-destructive">
                    {t("Enter a valid TikTok username.")}
                  </p>
                )}
                {parsed && (
                  <div className="mt-4 flex items-center gap-3 rounded-md border bg-surface-subtle p-3">
                    <div className="grid size-10 place-items-center rounded-full bg-primary text-xs font-semibold text-primary-foreground">
                      {displayName
                        .split(" ")
                        .map((part) => part[0])
                        .join("")
                        .slice(0, 2)}
                    </div>
                    <div>
                      <p className="text-sm font-medium">{displayName}</p>
                      <p className="text-xs text-muted-foreground">{parsed.handle}</p>
                    </div>
                    <CheckCircle2 className="ml-auto size-4 text-success" />
                  </div>
                )}
                {error && (
                  <p role="alert" className="mt-3 text-sm text-destructive">
                    {error}
                  </p>
                )}
              </div>
              <div className="mt-6 flex justify-end">
                <Button
                  disabled={!valid || createChannel.isPending}
                  onClick={() => void addChannel()}
                >
                  {createChannel.isPending ? (
                    <>
                      <span className="size-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
                      Adding channel…
                    </>
                  ) : (
                    <>
                      Add &amp; start monitoring
                      <ArrowRight />
                    </>
                  )}
                </Button>
              </div>
            </>
          )}
          {step === 3 && (
            <>
              <div className="flex items-center gap-4">
                <div className="grid size-12 place-items-center rounded-full bg-primary text-sm font-semibold text-primary-foreground">
                  {(createdHandle ?? "@ss")
                    .replace(/^@/, "")
                    .slice(0, 2)
                    .toUpperCase()}
                </div>
                <div>
                  <h1 className="text-xl font-semibold">
                    {displayNameFromTikTokUsername(createdHandle ?? "channel")}
                  </h1>
                  <p className="text-sm text-muted-foreground">{createdHandle}</p>
                </div>
                <Switch className="ml-auto" checked disabled />
              </div>
              <div className="mt-8 rounded-lg border bg-success-subtle p-5">
                <div className="flex items-center gap-2 font-medium text-success">
                  <CheckCircle2 className="size-5" />
                  Monitoring on
                </div>
                <p className="mt-2 text-sm text-muted-foreground">
                  You’re all set. SaveStream will monitor this channel and automatically start
                  recording according to its watch settings.
                </p>
              </div>
              <Button className="mt-8" asChild>
                <Link to="/channels">
                  View channels
                  <ArrowRight />
                </Link>
              </Button>
            </>
          )}
        </div>
      </main>
    </div>
  );
}
export function OverviewPage() {
  return isDemoMode ? <DemoOverviewPage /> : <ProductionOverviewPage />;
}

function ProductionOverviewPage() {
  const { t } = usePreferences();
  const { query: channelsQuery } = useChannelsData();
  const { query: recordingsQuery } = useRecordingsData();
  const { query: balanceQuery } = useCreditBalanceData();

  if (channelsQuery.isPending || recordingsQuery.isPending || balanceQuery.isPending) {
    return (
      <AppShell>
        <PageHeader title="Overview" subtitle="Loading workspace status…" action={<AddChannelDialog />} />
        <div className="h-40 animate-pulse rounded-lg border bg-muted" aria-busy="true" />
      </AppShell>
    );
  }

  if (channelsQuery.isError || recordingsQuery.isError || balanceQuery.isError || !balanceQuery.data) {
    return (
      <AppShell>
        <PageHeader title="Overview" action={<AddChannelDialog />} />
        <ErrorState
          title="Could not load workspace overview"
          body="SaveStream could not load one or more authoritative workspace resources."
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
  const overviewRecordings = recordingsQuery.data ?? [];
  const monitoredChannels = overviewChannels.filter((channel) => channel.monitoring).length;
  const activeRecordingStatuses = new Set([
    "queued",
    "resolving",
    "waiting_live",
    "recording",
    "processing",
    "uploading",
    "stop_requested",
  ]);
  const activeRecordings = overviewRecordings.filter((recording) =>
    activeRecordingStatuses.has(recording.backendStatus),
  ).length;
  const balance = balanceQuery.data;

  return (
    <AppShell>
      <PageHeader
        title="Overview"
        subtitle="Backend-authoritative workspace status."
        action={<AddChannelDialog />}
      />
      <div className="mb-6 grid overflow-hidden rounded-lg border sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Available credits"
          value={String(balance.available)}
          detail="Usable for new recordings"
          icon={Zap}
        />
        <StatCard
          label="Reserved credits"
          value={String(balance.reserved)}
          detail="Held for active recordings"
          icon={CreditCard}
        />
        <StatCard
          label="Monitored channels"
          value={String(monitoredChannels)}
          detail={`${overviewChannels.length} channels in workspace`}
          icon={Radio}
        />
        <StatCard
          label="Active recordings"
          value={String(activeRecordings)}
          detail={`${overviewRecordings.length} recordings in library`}
          icon={FileVideo}
        />
      </div>
      <ActiveRecordingCard />
      <div className="mt-8 grid gap-8 xl:grid-cols-[1.2fr_.8fr]">
        <section>
          <SectionTitle
            title="Channel monitoring"
            action={<Link to="/channels">{t("View all")}</Link>}
          />
          {overviewChannels.length ? (
            <>
              <div className="hidden overflow-hidden rounded-lg border bg-surface md:block">
                <div className="grid grid-cols-[1.5fr_.7fr_.7fr_.8fr_.6fr_auto] gap-4 border-b bg-surface-subtle px-4 py-2 text-[11px] font-medium uppercase text-muted-foreground">
                  <span>{t("Creator")}</span>
                  <span>{t("Platform")}</span>
                  <span>{t("Monitoring")}</span>
                  <span>{t("Status")}</span>
                  <span>{t("Checked")}</span>
                  <span />
                </div>
                {overviewChannels.map((channel) => (
                  <ChannelRow key={channel.id} channel={channel} />
                ))}
              </div>
              <div className="space-y-3 md:hidden">
                {overviewChannels.map((channel) => (
                  <ChannelCard key={channel.id} channel={channel} />
                ))}
              </div>
            </>
          ) : (
            <EmptyState
              icon={Radio}
              title="No channels yet"
              body="Add an authorized TikTok channel to start monitoring."
              action={<AddChannelDialog />}
            />
          )}
        </section>
        <section>
          <SectionTitle
            title="Recent recordings"
            action={<Link to="/recordings">{t("View library")}</Link>}
          />
          {overviewRecordings.length ? (
            <div className="divide-y rounded-lg border bg-surface">
              {overviewRecordings.slice(0, 3).map((recording) => (
                <Link
                  key={recording.id}
                  to="/recordings/$id"
                  params={{ id: recording.id }}
                  className="flex items-center gap-3 p-3"
                >
                  <div className={cn("aspect-video w-20 rounded", recording.color)} />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium">{recording.handle}</p>
                    <p className="text-xs text-muted-foreground">
                      {recording.date} · {recording.duration}
                    </p>
                  </div>
                  <StatusBadge status={recording.status} />
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

function DemoOverviewPage() {
  const { t } = usePreferences();
  const { query: channelsQuery } = useChannelsData();
  const { query: recordingsQuery } = useRecordingsData();
  const overviewChannels = channelsQuery.data ?? [];
  const overviewRecordings = recordingsQuery.data ?? [];
  return (
    <AppShell>
      <PageHeader title="Overview" subtitle="Sunday, September 27" action={<AddChannelDialog />} />
      <div className="mb-6 grid overflow-hidden rounded-lg border sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Recording hours"
          value="12.6 / 50 h"
          detail="25% used · resets Oct 1"
          icon={Clock3}
          progress={25}
        />
        <StatCard
          label="Active channels"
          value="3 / 5"
          detail="3 currently monitoring"
          icon={Radio}
        />
        <StatCard
          label="Stored recordings"
          value="18.4 GB"
          detail="4 recordings"
          icon={HardDrive}
        />
        <StatCard
          label="Download usage"
          value="24.8 / 100 GB"
          detail="25% used this month"
          icon={Download}
          progress={25}
        />
      </div>
      <ActiveRecordingCard />
      <div className="mt-8 grid gap-8 xl:grid-cols-[1.2fr_.8fr]">
        <section>
          <SectionTitle
            title="Channel monitoring"
            action={<Link to="/channels">{t("View all")}</Link>}
          />
          <div className="hidden overflow-hidden rounded-lg border bg-surface md:block">
            <div className="grid grid-cols-[1.5fr_.7fr_.7fr_.8fr_.6fr_auto] gap-4 border-b bg-surface-subtle px-4 py-2 text-[11px] font-medium uppercase text-muted-foreground">
              <span>{t("Creator")}</span>
              <span>{t("Platform")}</span>
              <span>{t("Monitoring")}</span>
              <span>{t("Status")}</span>
              <span>{t("Checked")}</span>
              <span />
            </div>
            {overviewChannels.map((c) => (
              <ChannelRow key={c.id} channel={c} />
            ))}
          </div>
          <div className="space-y-3 md:hidden">
            {overviewChannels.map((c) => (
              <ChannelCard key={c.id} channel={c} />
            ))}
          </div>
        </section>
        <section>
          <SectionTitle
            title="Recent recordings"
            action={<Link to="/recordings">{t("View library")}</Link>}
          />
          <div className="divide-y rounded-lg border bg-surface">
            {overviewRecordings.slice(0, 3).map((r) => (
              <Link
                key={r.id}
                to="/recordings/$id"
                params={{ id: r.id }}
                className="flex items-center gap-3 p-3"
              >
                <div className={cn("aspect-video w-20 rounded", r.color)} />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">{r.handle}</p>
                  <p className="text-xs text-muted-foreground">
                    {r.date} · {r.duration}
                  </p>
                </div>
                <StatusBadge status={r.status} />
              </Link>
            ))}
          </div>
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

export function ChannelsPage() {
  const { t } = usePreferences();
  const { query: channelsQuery, state: channelsState } = useChannelsData();
  const channelItems = channelsQuery.data ?? [];
  const [q, setQ] = useState("");
  const [filter, setFilter] = useState("All");
  const filtered = channelItems.filter(
    (c) =>
      (filter === "All" || c.status === filter) &&
      (c.name + c.handle).toLowerCase().includes(q.toLowerCase()),
  );
  return (
    <AppShell>
      <PageHeader
        title="Channels"
        subtitle="Channels are monitored automatically. Recording begins when an enabled channel goes live."
        action={<AddChannelDialog />}
      />
      <FilterBar>
        <SearchInput value={q} onChange={setQ} placeholder="Search channels" />
        <div className="flex gap-1 overflow-x-auto">
          {["All", "Recording", "Waiting", "Offline", "Paused", "Error"].map((f) => (
            <Button
              key={f}
              size="sm"
              variant={filter === f ? "secondary" : "ghost"}
              onClick={() => setFilter(f)}
            >
              {f}
            </Button>
          ))}
        </div>
      </FilterBar>
      {channelsState.kind === "loading" ? (
        <div className="space-y-3" aria-busy="true">
          {[0, 1, 2].map((i) => (
            <div key={i} className="h-20 animate-pulse rounded-lg border bg-muted" />
          ))}
        </div>
      ) : channelsState.kind === "error" ? (
        <ErrorState
          title="Could not load channels"
          body="The channel repository returned an error. Retry when the data source is available."
          onRetry={() => channelsQuery.refetch()}
        />
      ) : filtered.length ? (
        <>
          <div className="hidden overflow-hidden rounded-lg border bg-surface md:block">
            <div className="grid grid-cols-[1.5fr_.7fr_.7fr_.8fr_.6fr_auto] gap-4 border-b bg-surface-subtle px-4 py-2 text-[11px] font-medium uppercase text-muted-foreground">
              <span>{t("Creator")}</span>
              <span>{t("Platform")}</span>
              <span>{t("Monitoring")}</span>
              <span>{t("Status")}</span>
              <span>{t("Last checked")}</span>
              <span />
            </div>
            {filtered.map((c) => (
              <ChannelRow key={c.id} channel={c} />
            ))}
          </div>
          <div className="space-y-3 md:hidden">
            {filtered.map((c) => (
              <ChannelCard key={c.id} channel={c} />
            ))}
          </div>
        </>
      ) : (
        <EmptyState
          icon={Search}
          title="No channels found"
          body="Try another search or clear the current filter."
        />
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
                title={`${expiring.length} recordings expire soon`}
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
          body="Recording status is still refreshing from the backend every few seconds while the event stream reconnects."
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
  const { query: recordingQuery, state: recordingState } = useRecordingData(id);
  const { query: recordingsQuery, state: recordingsState } = useRecordingsData();
  const { query: channelsQuery } = useChannelsData();
  const stopRecording = useStopRecordingMutation();
  const deleteRecording = useDeleteRecordingMutation();
  const downloadRecording = useRecordingDownloadMutation();
  const [quota, setQuota] = useState<"normal" | "low">("normal");
  const [upgrade, setUpgrade] = useState(false);
  const [del, setDel] = useState(false);

  const rec = forced
    ? (recordingsQuery.data ?? []).find((item) => recordingMatchesForcedState(item, forced))
    : recordingQuery.data;
  const sourceState = forced ? recordingsState : recordingState;
  const realtime = useRecordingRealtime(rec?.id, rec?.backendStatus);
  const artifactState = rec ? (forced ?? recordingDetailState(rec)) : forced ?? null;
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
              ? "The backend does not currently have a recording in this state."
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
      candidate.id === rec.channelId ||
      candidate.handle.toLowerCase() === rec.handle.toLowerCase(),
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

    void downloadRecording
      .mutateAsync(rec.id)
      .then(({ download: signed }) => {
        window.location.assign(signed.url);
      })
      .catch((error) => {
        toast.error("Download unavailable", {
          description: artifactActionErrorMessage(error),
        });
        void artifactsQuery.refetch();
      });
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
            downloadRecording.isPending ||
            (!isDemoMode && (artifactsState.kind === "loading" || !artifact))
          }
        >
          <Download />
          {downloadRecording.isPending ? "Preparing…" : "Download video"}
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
          <Button
            variant="outline"
            disabled={downloadRecording.isPending}
            onClick={download}
          >
            <Download />
            {downloadRecording.isPending ? "Preparing…" : "Download partial"}
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
            body={`It will be removed from cloud storage when your ${usage.retentionDays}-day retention period ends. Download it to keep a copy.`}
            action={
              <Button size="sm" variant="outline" onClick={download}>
                Download
              </Button>
            }
          />
        </div>
      )}
      <VideoPlayerShell state={state} />
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
            tone={rec.backendStatus === "stopped" ? "info" : "error"}
            title={rec.backendStatus === "stopped" ? "Recording stopped" : "Recording couldn’t be completed"}
            body={
              rec.backendStatus === "stopped"
                ? "The recording was stopped before it completed."
                : rec.error || "The backend reported that this recording failed."
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
          ["Resolution", rec.resolution],
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
  const resolving = status === "queued" || status === "resolving" || status === "waiting_live";
  const processing = status === "processing";
  const uploading = status === "uploading";

  const stage = resolving ? 0 : processing ? 1 : uploading ? 2 : 3;
  const steps = [
    [Activity, resolving ? "Preparing recorder" : "Recording completed"],
    [Activity, "Processing video"],
    [Upload, "Uploading"],
    [CheckCircle2, "Ready"],
  ] as const;

  return (
    <div className="mt-5 rounded-lg border p-5">
      <h2 className="font-medium">Finalizing your recording</h2>
      <p className="mt-1 text-sm text-muted-foreground">
        The backend is updating this page in realtime as the recording moves through its lifecycle.
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
                {label}
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

function formatMoneyValue(money: Money, language: string) {
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

function formatCreditMoney(
  packageItem: CreditPackageResponse,
  language: string,
) {
  return formatMoneyValue(packageItem.price, language);
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
    const unit =
      unitSeconds % 60 === 0
        ? `${unitSeconds / 60} min`
        : `${unitSeconds} sec`;
    return `${creditsPerUnit} credit${creditsPerUnit === 1 ? "" : "s"} per ${unit}`;
  }
  return "The active backend pricing policy defines this rule.";
}

function creditTransactionTitle(transaction: CreditTransactionResponse) {
  if (transaction.type === "charge" && transaction.reference_type === "recording") {
    return "Recording charge";
  }
  if (transaction.type === "grant") return "Credits added";
  if (transaction.type === "refund") return "Credit refund";
  if (transaction.type === "adjustment") return "Credit adjustment";
  if (transaction.type === "release") return "Reservation released";
  return "Credit transaction";
}

function CreditTransactionRow({ transaction }: { transaction: CreditTransactionResponse }) {
  const amount = transaction.amount > 0 ? `+${transaction.amount}` : String(transaction.amount);
  return (
    <div className="grid gap-2 border-t px-4 py-3 text-sm sm:grid-cols-[1.5fr_.8fr_.8fr_auto] sm:items-center">
      <div>
        <p className="font-medium">{creditTransactionTitle(transaction)}</p>
        <p className="mt-1 text-xs text-muted-foreground">
          {new Date(transaction.created_at).toLocaleString()}
          {transaction.reference_id ? ` · ${transaction.reference_id}` : ""}
        </p>
      </div>
      <span className="font-mono">{transaction.type}</span>
      <span className="font-mono">Balance {transaction.balance_after}</span>
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
        <p className="font-medium">Recording {reservation.recording_id}</p>
        <p className="mt-1 text-xs text-muted-foreground">
          {new Date(reservation.created_at).toLocaleString()}
        </p>
      </div>
      <span className="font-mono">{reservation.status}</span>
      <span className="font-mono">Reserved {reservation.reserved}</span>
      <span className="font-mono">Settled {reservation.settled}</span>
      <span className="font-mono">Open {outstanding}</span>
    </div>
  );
}

function CreditsUsagePage() {
  const { t, language } = usePreferences();
  const { query: balanceQuery, state: balanceState } = useCreditBalanceData();
  const { query: transactionsQuery, state: transactionsState } =
    useCreditTransactionsData();
  const { query: reservationsQuery, state: reservationsState } =
    useCreditReservationsData();
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
          body="SaveStream could not load the authoritative credit account."
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
        subtitle="Backend-authoritative credit balance, reservations, and charges."
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
          title="SaveStream uses credits instead of monthly Free/Pro quotas"
          body="Available credits equal posted credits minus active reservations. Recording charges are calculated and settled by the backend pricing snapshot; this page does not estimate final charges."
        />
      </div>

      <div className="grid overflow-hidden rounded-lg border sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Available credits"
          value={String(balance.available)}
          detail="Usable for new recordings"
          icon={Zap}
        />
        <StatCard
          label="Posted credits"
          value={String(balance.posted)}
          detail="Ledger balance"
          icon={CreditCard}
        />
        <StatCard
          label="Reserved credits"
          value={String(balance.reserved)}
          detail="Held for active recordings"
          icon={Clock3}
        />
        <StatCard
          label="Active reservations"
          value={String(activeReservations.length)}
          detail="From the latest reservation page"
          icon={Radio}
        />
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <section className="rounded-lg border bg-surface p-5">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h2 className="font-medium">{t("Current pricing")}</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                Public rules from the active backend pricing version.
              </p>
            </div>
            {pricing && (
              <span className="rounded-md bg-muted px-2 py-1 font-mono text-xs">
                {pricing.version}
              </span>
            )}
          </div>
          {pricingState.kind === "error" ? (
            <div className="mt-5">
              <StateBanner
                tone="warning"
                title="Pricing unavailable"
                body="The backend does not currently have a readable active pricing rule."
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
                    <p className="mt-1 text-xs text-muted-foreground">
                      {pricingRuleDetail(rule)}
                    </p>
                  </div>
                ))
              ) : (
                <p className="text-sm text-muted-foreground">
                  No public pricing rules are exposed by the current backend version.
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
            Packages currently enabled by the billing backend.
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
                      {item.credits} credits
                    </p>
                  </div>
                  <p className="font-mono font-semibold">
                    {formatCreditMoney(item, language)}
                  </p>
                </div>
              ))}
              <p className="text-xs text-muted-foreground">
                Checkout is handled separately by the billing flow.
              </p>
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
          <h2 className="font-medium">Active and recent reservations</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Reservations hold credits while recordings are in progress. Unused reserved credit is
            released by the backend.
          </p>
        </div>
        {reservationsState.kind === "error" ? (
          <div className="p-5">
            <StateBanner
              tone="warning"
              title="Reservations unavailable"
              body="SaveStream could not load recent credit reservations."
              action={
                <Button size="sm" variant="outline" onClick={() => void reservationsQuery.refetch()}>
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
          <p className="p-5 text-sm text-muted-foreground">No credit reservations yet.</p>
        )}
      </section>

      <section className="mt-8 rounded-lg border bg-surface">
        <div className="border-b p-5">
          <h2 className="font-medium">Recent credit transactions</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Ledger entries returned by the backend. Corrections appear as compensating entries.
          </p>
        </div>
        {transactionsState.kind === "error" ? (
          <div className="p-5">
            <StateBanner
              tone="warning"
              title="Transactions unavailable"
              body="SaveStream could not load recent credit transactions."
              action={
                <Button size="sm" variant="outline" onClick={() => void transactionsQuery.refetch()}>
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
          <p className="p-5 text-sm text-muted-foreground">No credit transactions yet.</p>
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
            title="You’ve used 80% of your monthly recording hours."
            body={`${hours} of ${usage.recordingHours.limit} hours used. Recording continues normally until the limit, then pauses until ${usage.resetsOn}.`}
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
}: {
  order: PaymentOrderResponse;
  language: string;
  onContinue: (id: string) => void;
  pending: boolean;
}) {
  return (
    <div className="grid gap-3 border-t px-5 py-4 text-sm sm:grid-cols-[1.3fr_.7fr_.7fr_auto] sm:items-center">
      <div>
        <p className="font-medium">{order.credits} credits</p>
        <p className="mt-1 font-mono text-xs text-muted-foreground">{order.id}</p>
        <p className="mt-1 text-xs text-muted-foreground">
          {new Date(order.created_at).toLocaleString()}
          {order.provider ? ` · ${order.provider}` : ""}
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
      {billingCheckoutEnabled && isAwaitingPaymentConfirmation(order.status) ? (
        <Button
          size="sm"
          variant="outline"
          disabled={pending}
          onClick={() => onContinue(order.id)}
        >
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
  const [activePurchase, setActivePurchase] = useState<string | null>(null);

  const redirectToCheckout = async (
    input: BillingCheckoutInput,
    activeId: string,
  ) => {
    setActivePurchase(activeId);
    try {
      const result = await checkout.mutateAsync(input);
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
          body="SaveStream could not load the current credit account."
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
        subtitle="Buy SaveStream credits through secure hosted checkout."
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
            title="Checkout is disabled for this deployment"
            body="Hosted checkout is enabled only on explicitly configured environments. Staging uses Lemon Squeezy Test Mode; production stays disabled until Live Mode is approved and configured."
          />
        </div>
      )}

      <div className="grid overflow-hidden rounded-lg border sm:grid-cols-3">
        <StatCard
          label="Available credits"
          value={String(balance.available)}
          detail="Available for new recordings"
          icon={Zap}
        />
        <StatCard
          label="Posted balance"
          value={String(balance.posted)}
          detail="Backend ledger balance"
          icon={CreditCard}
        />
        <StatCard
          label="Reserved"
          value={String(balance.reserved)}
          detail="Held by active recordings"
          icon={Clock3}
        />
      </div>

      <section className="mt-8">
        <div className="mb-4">
          <h2 className="text-lg font-semibold">Credit packages</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Choose a package, then complete payment on the hosted payment-provider checkout.
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
                  <p className="mt-2 text-sm text-muted-foreground">{item.credits} credits</p>
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
                        : "Checkout disabled"}
                  </Button>
                </div>
              );
            })}
          </div>
        ) : packagesState.kind === "empty" ? (
          <EmptyState
            icon={CreditCard}
            title="No active packages"
            body="The billing backend does not currently expose a package for purchase."
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
            <h2 className="font-medium">Recent payment orders</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Payment status comes from the SaveStream backend, not from the browser redirect.
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
              body="SaveStream could not load your recent payment orders."
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
              onContinue={(orderId) =>
                void redirectToCheckout({ kind: "order", orderId }, orderId)
              }
            />
          ))
        ) : (
          <p className="border-t p-5 text-sm text-muted-foreground">
            No payment orders yet.
          </p>
        )}
      </section>

      <div className="mt-8">
        <StateBanner
          tone="info"
          title="Payment confirmation is server-side"
          body="Opening checkout only creates a pending payment order. Credits are added only after a verified payment webhook or reconciliation confirms the order as paid."
        />
      </div>
    </AppShell>
  );
}

function DemoBillingPage() {
  const { t, language } = usePreferences();
  const navigate = useNavigate();
  const [mock, setMock] = useState<(typeof billingStates)[number]["value"]>("active");
  const [upgrade, setUpgrade] = useState(false);
  const [cancel, setCancel] = useState(false);
  const isPro = mock !== "free";
  const pro = planCatalog.pro;
  const free = planCatalog.free;
  const pm = subscription.paymentMethod;
  const manage = () =>
    toast(t("Demo function"), {
      description: t("Payment provider isn’t connected in this prototype."),
    });
  const invoiceRows =
    mock === "payment_failed" || mock === "past_due"
      ? [
          {
            id: "INV-2026-0010",
            date: "Sep 27, 2026",
            description: "Pro · Monthly",
            amount: formatCurrencyUsd(pro.priceMonthlyUsd, language),
            status: "Failed" as const,
          },
          ...invoices,
        ]
      : mock === "free"
        ? []
        : invoices;

  return (
    <AppShell>
      <PageHeader title="Billing" subtitle="Manage your plan, payment method, and invoices." />
      <PrototypeStateBar value={mock} options={billingStates} onChange={setMock} />
      <div className="mb-6 space-y-3">
        {mock === "payment_failed" && (
          <StateBanner
            tone="error"
            title="Payment failed"
            body="This is an illustrative payment-failure state. No real charge was attempted."
            action={<Button size="sm" onClick={manage}>{t("Update payment method")}</Button>}
          />
        )}
        {mock === "past_due" && (
          <StateBanner
            tone="error"
            title="Past due"
            body="This is an illustrative past-due state for the frontend demo."
            action={<Button size="sm" onClick={manage}>{t("Pay now")}</Button>}
          />
        )}
        {mock === "canceling" && (
          <StateBanner
            tone="info"
            title="Cancellation scheduled"
            body={`${t("Demo function")}: ${formatDate(subscription.currentPeriodEnd, language)}`}
            action={
              <Button
                size="sm"
                variant="outline"
                onClick={() => {
                  setMock("active");
                  toast.success(t("Subscription resumed"));
                }}
              >
                {t("Resume subscription")}
              </Button>
            }
          />
        )}
      </div>

      <section className="mb-8 rounded-lg border bg-surface">
        <div className="flex flex-col gap-4 p-5 sm:flex-row sm:items-center">
          <div className="flex-1">
            <p className="text-xs text-muted-foreground">{t("Current subscription")}</p>
            <div className="mt-1 flex flex-wrap items-center gap-2">
              <h2 className="text-lg font-semibold">{isPro ? "Pro" : "Free"}</h2>
              <span className="rounded-md border bg-muted px-2 py-0.5 text-xs font-medium">
                {t(mock === "active" ? "Active" : mock === "free" ? "Free" : mock === "past_due" ? "Past due" : mock === "payment_failed" ? "Payment failed" : "Demo")}
              </span>
            </div>
            <p className="mt-1 text-sm text-muted-foreground">
              {isPro
                ? `${formatCurrencyUsd(pro.priceMonthlyUsd, language)} · ${t("Monthly")}`
                : t("Free")}
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            {isPro ? (
              <>
                <Button variant="outline" onClick={manage}>{t("Manage subscription")}</Button>
                {mock !== "canceling" && (
                  <Button variant="ghost" onClick={() => setCancel(true)}>{t("Cancel subscription")}</Button>
                )}
              </>
            ) : (
              <Button onClick={() => setUpgrade(true)}><Sparkles />{t("Upgrade to Pro")}</Button>
            )}
          </div>
        </div>
      </section>

      <div className="mb-4">
        <h2 className="text-sm font-semibold">{t("Plans")}</h2>
        <p className="mt-1 text-xs text-muted-foreground">{t("Simple plans with one monthly source of truth.")}</p>
      </div>
      <div className="grid gap-5 lg:grid-cols-2">
        <PlanCard
          name={free.name}
          price="Free"
          current={!isPro}
          features={[...free.features]}
          action={
            isPro ? (
              <Button variant="outline" className="mt-6 w-full" onClick={() => setCancel(true)} disabled={mock === "canceling"}>
                {t(mock === "canceling" ? "Switching Oct 1" : "Downgrade to Free")}
              </Button>
            ) : (
              <Button variant="outline" className="mt-6 w-full" disabled>{t("Current plan")}</Button>
            )
          }
        />
        <PlanCard
          name={pro.name}
          price={formatCurrencyUsd(pro.priceMonthlyUsd, language)}
          current={isPro}
          features={[...pro.features]}
          action={
            isPro ? (
              <Button variant="outline" className="mt-6 w-full" onClick={manage}>{t("Manage plan")}</Button>
            ) : (
              <Button className="mt-6 w-full" onClick={() => setUpgrade(true)}>{t("Upgrade to Pro")}</Button>
            )
          }
        />
      </div>
      <div className="mt-4 rounded-md border bg-surface-subtle p-4 text-xs text-muted-foreground">
        <p className="font-medium text-foreground">{t("Plan limits")}</p>
        <dl className="mt-2 grid gap-2 sm:grid-cols-3">
          {planLimitDefinitions.map((item) => (
            <div key={item.key}>
              <dt className="font-medium">{t(item.label)}</dt>
              <dd>{t(item.description)}</dd>
            </div>
          ))}
        </dl>
        <p className="mt-3">{t(planMediaFootnote)}</p>
      </div>

      <div className="mt-8 grid gap-6 lg:grid-cols-[.8fr_1.2fr]">
        <section className="rounded-lg border bg-surface">
          <div className="border-b p-5">
            <h2 className="font-medium">{t("Payment method")}</h2>
            <p className="mt-1 text-sm text-muted-foreground">{t("Used for your Pro subscription.")}</p>
          </div>
          {isPro && pm ? (
            <div className="flex items-center gap-3 p-5">
              <span className="grid size-10 place-items-center rounded-md border"><CreditCard className="size-4" /></span>
              <div>
                <p className="text-sm font-medium">{pm.brand} •••• {pm.last4}</p>
                <p className="text-xs text-muted-foreground">{pm.exp}</p>
              </div>
              <Button className="ml-auto" variant="outline" onClick={manage}>{t("Update")}</Button>
            </div>
          ) : (
            <p className="p-5 text-sm text-muted-foreground">{t("No payment method on file.")}</p>
          )}
        </section>
        <section className="rounded-lg border bg-surface">
          <div className="border-b p-5"><h2 className="font-medium">{t("Billing history")}</h2></div>
          {invoiceRows.length ? (
            <ul className="divide-y">
              {invoiceRows.map((inv) => (
                <li key={inv.id} className="grid grid-cols-[1fr_auto] items-center gap-3 px-5 py-3 text-sm sm:grid-cols-[1fr_1fr_auto_auto_auto]">
                  <div>
                    <p className="font-medium">{formatDate(inv.date, language)}</p>
                    <p className="font-mono text-xs text-muted-foreground">{inv.id}</p>
                  </div>
                  <span className="hidden text-muted-foreground sm:block">{inv.description}</span>
                  <span className="font-mono">{inv.amount}</span>
                  <span className="hidden rounded-md bg-muted px-2 py-0.5 text-xs font-medium sm:inline">{t(inv.status)}</span>
                  <Button
                    variant="ghost"
                    size="icon"
                    aria-label={`${t("Download invoice")} ${inv.id}`}
                    className="hidden sm:inline-flex"
                    onClick={() => toast(t("Invoice download is mocked"))}
                  >
                    <Download />
                  </Button>
                </li>
              ))}
            </ul>
          ) : (
            <p className="p-5 text-sm text-muted-foreground">{t("No invoices yet.")}</p>
          )}
        </section>
      </div>

      <Dialog open={upgrade} onOpenChange={setUpgrade}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("Upgrade to Pro?")}</DialogTitle>
            <DialogDescription>
              {formatCurrencyUsd(pro.priceMonthlyUsd, language)} {t("/ month")}. {t("Secure checkout is not connected in this frontend demo.")}
            </DialogDescription>
          </DialogHeader>
          <ul className="space-y-2 rounded-md border bg-surface-subtle p-4 text-sm">
            {pro.features.map((feature) => (
              <li key={feature} className="flex gap-2"><CheckCircle2 className="size-4 text-success" />{t(feature)}</li>
            ))}
          </ul>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setUpgrade(false)}>{t("Cancel")}</Button>
            <Button onClick={() => { setUpgrade(false); navigate({ to: "/billing/success", search: { order_id: "demo-paid" } }); }}>
              {t("Continue to checkout")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        destructive
        open={cancel}
        onOpenChange={setCancel}
        title="Cancel Pro subscription?"
        body="This demo only changes local UI state. No subscription or payment service is connected."
        confirmLabel="Cancel subscription"
        onConfirm={() => {
          setCancel(false);
          setMock("canceling");
          toast(t("Subscription canceled"));
        }}
      />
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
      <PageHeader
        title="System"
        subtitle="Illustrative admin metrics for the frontend demo."
      />
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

function CreditPricingPage() {
  const { t, language } = usePreferences();
  const { status } = useAuth();
  const authenticated = status === "authenticated";
  const { query: pricingQuery, state: pricingState } = usePricingData(authenticated);
  const { query: packagesQuery, state: packagesState } = useCreditPackagesData(authenticated);
  const pricing = pricingQuery.data;
  const packages = packagesQuery.data?.items ?? [];

  return (
    <>
      <PublicHeader />
      <main className="mx-auto max-w-5xl px-4 pb-20 pt-32">
        <div className="text-center">
          <h1 className="text-4xl font-semibold">Credit-based pricing for livestream recording.</h1>
          <p className="mx-auto mt-4 max-w-2xl text-muted-foreground">
            SaveStream uses integer credits. Recording costs are determined by the active backend
            pricing policy and settled after recording usage is known.
          </p>
        </div>

        {!authenticated ? (
          <>
            <div className="mx-auto mt-10 max-w-3xl">
              <StateBanner
                tone="info"
                icon={CreditCard}
                title="Sign in to view current packages and active pricing"
                body="The current pricing and package APIs require an authenticated SaveStream account. We do not show stale Free/Pro prices or invent public package values here."
                action={
                  <div className="flex flex-wrap gap-2">
                    <Button size="sm" asChild>
                      <Link to="/sign-in">{t("Sign in")}</Link>
                    </Button>
                    <Button size="sm" variant="outline" asChild>
                      <Link to="/sign-up">{t("Create account")}</Link>
                    </Button>
                  </div>
                }
              />
            </div>
            <div className="mt-10 grid gap-5 md:grid-cols-3">
              {[
                [
                  "Credits, not monthly plan quotas",
                  "The production backend tracks posted, reserved, and available credits instead of the old Free/Pro monthly usage model.",
                ],
                [
                  "Backend pricing is authoritative",
                  "Clients display the active public pricing rules but do not calculate or guess the final recording charge.",
                ],
                [
                  "Unused reservations are released",
                  "Credits reserved for a recording are settled or released by the backend as the recording lifecycle completes.",
                ],
              ].map(([title, body]) => (
                <section key={title} className="rounded-lg border bg-surface p-5 text-left">
                  <h2 className="font-medium">{title}</h2>
                  <p className="mt-2 text-sm leading-6 text-muted-foreground">{body}</p>
                </section>
              ))}
            </div>
          </>
        ) : (
          <>
            <section className="mt-10 rounded-lg border bg-surface p-5">
              <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <h2 className="font-medium">Current backend pricing</h2>
                  <p className="mt-1 text-sm text-muted-foreground">
                    Public rules exposed by the active pricing configuration.
                  </p>
                </div>
                {pricing && (
                  <span className="w-fit rounded-md bg-muted px-2 py-1 font-mono text-xs">
                    {pricing.version}
                  </span>
                )}
              </div>
              {pricingState.kind === "error" ? (
                <div className="mt-5">
                  <StateBanner
                    tone="warning"
                    title="Pricing unavailable"
                    body="The active pricing policy could not be loaded."
                    action={
                      <Button size="sm" variant="outline" onClick={() => void pricingQuery.refetch()}>
                        Retry
                      </Button>
                    }
                  />
                </div>
              ) : pricing ? (
                <div className="mt-5 grid gap-3 md:grid-cols-2">
                  {pricing.rules.length ? (
                    pricing.rules.map((rule, index) => (
                      <div key={String(rule["code"] ?? index)} className="rounded-md border p-4">
                        <p className="text-sm font-medium">{pricingRuleTitle(rule, index)}</p>
                        <p className="mt-1 text-xs text-muted-foreground">
                          {pricingRuleDetail(rule)}
                        </p>
                      </div>
                    ))
                  ) : (
                    <p className="text-sm text-muted-foreground">
                      No public pricing rules are exposed by the current backend version.
                    </p>
                  )}
                </div>
              ) : (
                <div className="mt-5 h-28 animate-pulse rounded-md bg-muted" />
              )}
            </section>

            <section className="mt-8">
              <div className="mb-4">
                <h2 className="text-lg font-semibold">Available credit packages</h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  Packages currently enabled by the billing backend.
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
                <div className="grid gap-5 md:grid-cols-2">
                  {packages.map((item) => (
                    <div key={item.id} className="rounded-lg border bg-surface p-6">
                      <p className="text-lg font-semibold">{item.name}</p>
                      <p className="mt-3 font-mono text-3xl font-semibold">
                        {formatCreditMoney(item, language)}
                      </p>
                      <p className="mt-2 text-sm text-muted-foreground">
                        {item.credits} credits
                      </p>
                      <Button className="mt-6 w-full" variant="outline" asChild>
                        <Link to="/billing">Open billing</Link>
                      </Button>
                    </div>
                  ))}
                </div>
              ) : packagesState.kind === "empty" ? (
                <EmptyState
                  icon={CreditCard}
                  title="No credit packages available"
                  body="The billing backend does not currently expose an active package."
                />
              ) : (
                <div className="grid gap-5 md:grid-cols-2">
                  <div className="h-40 animate-pulse rounded-lg border bg-muted" />
                  <div className="h-40 animate-pulse rounded-lg border bg-muted" />
                </div>
              )}
            </section>
          </>
        )}
      </main>
      <PublicFooter />
    </>
  );
}

function DemoPricingPage() {
  const { t, language } = usePreferences();
  return (
    <>
      <PublicHeader />
      <main className="mx-auto max-w-5xl px-4 pb-20 pt-32">
        <div className="text-center">
          <h1 className="text-4xl font-semibold">{t("Plans that scale with your livestreams.")}</h1>
          <p className="mt-4 text-muted-foreground">{t("Start free. Upgrade when you need more recording time.")}</p>
        </div>
        <div className="mt-12 grid gap-5 md:grid-cols-2">
          {planList.map((plan) => (
            <PlanCard
              key={plan.id}
              name={plan.name}
              price={plan.priceMonthlyUsd ? formatCurrencyUsd(plan.priceMonthlyUsd, language) : "Free"}
              features={[...plan.features]}
              action={
                <Button variant={plan.id === "pro" ? "default" : "outline"} className="mt-6 w-full" asChild>
                  <Link to="/sign-up">{t(plan.id === "pro" ? "Start with Pro" : "Start for free")}</Link>
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
                <dd className="mt-1 text-xs leading-5 text-muted-foreground">{t(item.description)}</dd>
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
        ["/pricing", "Pricing"],
        ["/status", "Status"],
        ["/help", "Help"],
      ],
    ],
    [
      "Legal",
      [
        ["/terms", "Terms"],
        ["/privacy", "Privacy"],
        ["/acceptable-use", "Acceptable use"],
      ],
    ],
    [
      "Account",
      [
        ["/sign-in", "Sign in"],
        ["/sign-up", "Create account"],
      ],
    ],
  ];
  return (
    <footer className="border-t py-12">
      <div className="mx-auto grid max-w-7xl gap-10 px-4 sm:px-6 md:grid-cols-[1.5fr_repeat(3,1fr)]">
        <div>
          <Logo />
          <p className="mt-4 max-w-xs text-xs leading-5 text-muted-foreground">
            Cloud recording for TikTok channels you own, manage, or have permission to record.
          </p>
        </div>
        {cols.map(([h, links]) => (
          <div key={h}>
            <p className="text-xs font-semibold uppercase text-muted-foreground">{t(h)}</p>
            <ul className="mt-3 space-y-2 text-sm">
              {links.map(([to, l]) => (
                <li key={to}>
                  <Link
                    to={to as "/pricing"}
                    className="text-muted-foreground hover:text-foreground"
                  >
                    {t(l)}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
      <p className="mx-auto mt-10 max-w-7xl px-4 text-xs text-muted-foreground sm:px-6">
        © 2026 SaveStream. Record only channels you’re authorized to manage.
      </p>
    </footer>
  );
}
export function AuthLayout({ children }: { children: ReactNode }) {
  const { t } = usePreferences();
  return (
    <div className="grid min-h-screen bg-surface-subtle lg:grid-cols-[1fr_1.1fr]">
      <div className="flex flex-col bg-background p-6 sm:p-10">
        <Logo />
        <div className="m-auto w-full max-w-sm py-12">{children}</div>
      </div>
      <div className="hidden place-items-center overflow-hidden bg-auth lg:grid">
        <div className="max-w-lg px-10">
          <Cloud className="size-10 text-primary" />
          <p className="mt-8 text-3xl font-medium leading-tight">
            “We monitor. We record. You can close the browser.”
          </p>
          <div className="mt-8 flex items-center gap-3 text-sm text-muted-foreground">
            <span className="size-2 animate-pulse rounded-full bg-recording" />
            Recording @linastudio · 01:42:18
          </div>
        </div>
      </div>
    </div>
  );
}
const channelStates = [
  { value: "Recording", label: "Recording" },
  { value: "Waiting", label: "Waiting" },
  { value: "Offline", label: "Offline" },
  { value: "Paused", label: "Paused" },
  { value: "Error", label: "Error" },
] as const;
function ChannelDetail({
  channel,
  history,
  onRefresh,
}: {
  channel: ChannelModel;
  history: RecordingModel[];
  onRefresh: () => Promise<unknown>;
}) {
  const { t } = usePreferences();
  const navigate = useNavigate();
  const pauseChannel = usePauseChannelMutation();
  const resumeChannel = useResumeChannelMutation();
  const deleteChannel = useDeleteChannelMutation();
  const [previewState, setPreviewState] = useState<ChannelStatus>(channel.status);
  const [dialog, setDialog] = useState<null | "pause" | "remove">(null);
  const state = isDemoMode ? previewState : channel.status;
  const monitoring = isDemoMode
    ? state !== "Paused"
    : channel.backendStatus === "active";
  const pending =
    pauseChannel.isPending || resumeChannel.isPending || deleteChannel.isPending;

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

  const card = {
    Recording: (
      <>
        <div className="flex items-center justify-between">
          <p className="text-sm font-medium">Live status</p>
          <StatusBadge status="Recording" />
        </div>
        <p className="mt-6 text-sm font-medium text-recording">Recording now</p>
        <p className="mt-1 text-sm text-muted-foreground">
          SaveStream is recording this livestream on the server.
        </p>
        <p className="mt-4 flex items-center gap-2 text-xs text-muted-foreground">
          <Cloud className="size-4 text-success" />
          You can safely close this page.
        </p>
        <Button className="mt-5" asChild>
          <Link to="/recordings/active">View active recording</Link>
        </Button>
      </>
    ),
    Waiting: (
      <>
        <div className="flex items-center justify-between">
          <p className="text-sm font-medium">Live status</p>
          <StatusBadge status="Waiting" />
        </div>
        <p className="mt-6 font-medium">Waiting for the next livestream</p>
        <p className="mt-1 text-sm text-muted-foreground">
          Monitoring is on. Recording starts automatically when {channel.handle} goes live.
        </p>
        <dl className="mt-5 grid grid-cols-2 gap-3 text-sm">
          <div>
            <dt className="text-xs text-muted-foreground">{t("Last checked")}</dt>
            <dd className="mt-1 font-mono">{channel.checked}</dd>
          </div>
          <div>
            <dt className="text-xs text-muted-foreground">Last live</dt>
            <dd className="mt-1">{channel.live}</dd>
          </div>
        </dl>
      </>
    ),
    Offline: (
      <>
        <div className="flex items-center justify-between">
          <p className="text-sm font-medium">Live status</p>
          <StatusBadge status="Offline" />
        </div>
        <p className="mt-6 font-medium">Channel is offline</p>
        <p className="mt-1 text-sm text-muted-foreground">
          Monitoring is on. SaveStream will check again automatically.
        </p>
        <dl className="mt-5 grid grid-cols-2 gap-3 text-sm">
          <div>
            <dt className="text-xs text-muted-foreground">{t("Last checked")}</dt>
            <dd className="mt-1 font-mono">{channel.checked}</dd>
          </div>
          <div>
            <dt className="text-xs text-muted-foreground">Last live</dt>
            <dd className="mt-1">{channel.live}</dd>
          </div>
        </dl>
      </>
    ),
    Paused: (
      <>
        <div className="flex items-center justify-between">
          <p className="text-sm font-medium">Live status</p>
          <StatusBadge status="Paused" />
        </div>
        <p className="mt-6 font-medium">Monitoring is paused</p>
        <p className="mt-1 text-sm text-muted-foreground">
          Future livestreams from {channel.handle} will not be recorded until you resume monitoring.
          Existing recordings are not affected.
        </p>
        <Button className="mt-5" disabled={pending} onClick={() => void resume()}>
          <Radio />
          Resume monitoring
        </Button>
      </>
    ),
    Error: (
      <>
        <div className="flex items-center justify-between">
          <p className="text-sm font-medium">Live status</p>
          <StatusBadge status="Error" />
        </div>
        <p className="mt-6 font-medium">We couldn’t check live status</p>
        <p className="mt-1 text-sm text-muted-foreground">
          The most recent watch check failed. SaveStream will retry according to the backend
          scheduler.
        </p>
        <Button
          className="mt-5"
          variant="outline"
          onClick={() => {
            toast("Refreshing channel status…");
            void onRefresh();
          }}
        >
          Refresh status
        </Button>
      </>
    ),
  }[state];

  return (
    <AppShell>
      <Link
        to="/channels"
        className="mb-4 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="size-4" />
        Channels
      </Link>
      {isDemoMode && (
        <PrototypeStateBar
          label="Preview channel state"
          value={previewState}
          options={channelStates}
          onChange={setPreviewState}
        />
      )}
      <div className="mb-6 flex flex-col gap-4 border-y bg-surface px-5 py-4 sm:flex-row sm:items-center">
        <div className="flex items-center gap-4">
          <CreatorAvatar channel={channel} size="lg" />
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-xl font-semibold">{channel.name}</h1>
              <PlatformBadge />
            </div>
            <p className="text-sm text-muted-foreground">{channel.handle}</p>
          </div>
        </div>
        <div className="flex items-center gap-3 text-sm sm:ml-auto">
          <label htmlFor="detail-monitoring">{t("Monitoring")}</label>
          <Switch
            id="detail-monitoring"
            checked={monitoring}
            disabled={pending}
            onCheckedChange={toggle}
          />
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" aria-label="More channel actions">
                <MoreHorizontal />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem
                onSelect={() =>
                  window.open(`https://www.tiktok.com/${channel.handle}`, "_blank", "noopener")
                }
              >
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
        </div>
      </div>
      <div className="grid gap-6 lg:grid-cols-[1fr_1.5fr]">
        <section
          className={cn(
            "rounded-lg border bg-surface p-5",
            state === "Recording" && "border-recording/30",
            state === "Error" && "border-destructive/30",
          )}
        >
          {card}
        </section>
        <div className="grid grid-cols-2 overflow-hidden rounded-lg border">
          <StatCard
            label="Total recordings"
            value={String(channel.recordings)}
            detail="All time"
            icon={FileVideo}
          />
          <StatCard
            label="Recorded hours"
            value={channel.recordedHours}
            detail="All time"
            icon={Clock3}
          />
          <StatCard
            label="Last livestream"
            value={state === "Recording" ? "Now" : channel.live.split(",")[0] ?? "—"}
            detail={state === "Recording" ? "Currently recording" : channel.live}
            icon={Radio}
          />
          <StatCard
            label="Storage used"
            value={channel.storage}
            detail={`${history.length} retained files`}
            icon={HardDrive}
          />
        </div>
      </div>
      <section className="mt-8">
        <SectionTitle title="Recording history" />
        {history.length ? (
          <>
            <div className="hidden overflow-hidden rounded-lg border bg-surface lg:block">
              <RecordingHeader />
              {history.map((recording) => (
                <RecordingRow key={recording.id} recording={recording} />
              ))}
            </div>
            <div className="grid gap-3 sm:grid-cols-2 lg:hidden">
              {history.map((recording) => (
                <RecordingCard key={recording.id} recording={recording} />
              ))}
            </div>
          </>
        ) : (
          <EmptyState
            title="No recordings yet"
            body="The next livestream from this channel will appear here automatically."
          />
        )}
      </section>
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
const billingStates = [
  { value: "active", label: "Pro active" },
  { value: "free", label: "Free plan" },
  { value: "payment_failed", label: "Payment failed" },
  { value: "past_due", label: "Past due" },
  { value: "canceling", label: "Canceled, active until" },
] as const;