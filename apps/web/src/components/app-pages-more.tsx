import { SUPPORT_RESPONSE_TIME } from "@/lib/support";
import {
  PublicContactPage,
  PublicStatusPage,
  type ContactChannel,
} from "@/components/public/contact-status";
import { Link, useNavigate, useParams, useRouterState } from "@tanstack/react-router";
import { Fragment, useEffect, useRef, useState, type ReactNode } from "react";
import {
  AlertCircle,
  AlertTriangle,
  ArrowLeft,
  Bell,
  Check,
  CheckCircle2,
  ChevronRight,
  CircleHelp,
  Clock3,
  Cloud,
  CreditCard,
  Download,
  FileVideo,
  Gauge,
  Gift,
  KeyRound,
  LifeBuoy,
  Link2Off,
  Mail,
  Monitor,
  MoreHorizontal,
  Radio,
  RotateCcw,
  Search,
  Server,
  ShieldCheck,
  Smartphone,
  Trash2,
  XCircle,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
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
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import {
  AppShell,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  FilterBar,
  PageHeader,
  PasswordField,
  PrototypeStateBar,
  SearchInput,
  StateBanner,
  StatCard,
  StatusBadge,
  SuccessState,
  NotificationItem,
  AdminHealthBadge,
} from "@/components/app-components";
import { PublicFooter, PublicHeader, SectionTitle, formatMoneyValue } from "@/components/app-pages";
import { firebaseSocialConfigured } from "@/lib/firebase-social-login";
import {
  AppleIcon,
  AuthCardLayout,
  GoogleIcon,
  IconTile,
  ONE_TIME_LINK_MINUTES,
  SocialButton,
  trialMinutes,
  useTrialMinutesLabel,
} from "@/components/auth/auth-ui";
import {
  jobList,
  publicServices,
  sessions as seedSessions,
  systemEvents,
  user,
  usage,
  workerList,
  type EventSeverity,
  type JobEvent,
  type RecordingJob,
  type Worker,
  type WorkerStatus,
} from "@/mocks/fixtures";
import { notificationStore, useNotificationFeed } from "@/lib/notification-store";
import type { NotificationModel } from "@/repositories";
import { pluralize } from "@/lib/formatters";
import { cn } from "@/lib/utils";
import { describeUserAgent } from "@/lib/user-agent";
import { usePreferences } from "@/lib/preferences";
import { authApi, authErrorMessage } from "@/api/auth";
import type {
  AuditLogResponse,
  PaymentOrderResponse,
  PaymentStatusValue,
  RecordingResponse,
  RecordingStatusValue,
  EmailPreferenceKey,
  NotificationPreferencesResponse,
} from "@/api/types";
import { useAuth } from "@/auth/auth-context";
import { isDemoMode } from "@/lib/app-config";
import { track } from "@/lib/analytics";
import {
  useCurrentUserData,
  usePublicPricingData,
  useSessionsData,
  useCreditBalanceData,
} from "@/hooks/use-domain-data";
import { retentionSentence } from "@/lib/plan-facts";
import {
  useNotificationPreferencesData,
  useUpdateNotificationPreferencesMutation,
} from "@/hooks/use-notifications";
import {
  accountActionErrorMessage,
  useDeleteAccountMutation,
  useExportAccountMutation,
  useRequestPasswordResetMutation,
  useResendVerificationMutation,
  useRevokeSessionMutation,
  useUpdateProfileMutation,
} from "@/hooks/use-account-settings";
import { isAwaitingPaymentConfirmation, useBillingReturnOrder } from "@/hooks/use-billing";
import {
  useAdminAuditData,
  useAdminOperationalSnapshotData,
  useAdminRecordingData,
  useAdminRecordingsData,
  useAdminRetryRecordingMutation,
} from "@/hooks/use-admin-data";

const mono = "font-mono text-xs";

/* ---------------- Auth: verification & errors ---------------- */
export function VerifyEmailPage({ token = "" }: { token?: string }) {
  const { t } = usePreferences();
  const navigate = useNavigate();
  const [cooldown, setCooldown] = useState(0);
  const [email, setEmail] = useState(isDemoMode ? user.email : "");
  const [error, setError] = useState<string | null>(null);
  const [verifying, setVerifying] = useState(Boolean(token && !isDemoMode));
  const [sent, setSent] = useState(false);
  const verificationStarted = useRef(false);

  useEffect(() => {
    if (isDemoMode || typeof window === "undefined") return;
    const pending = window.sessionStorage.getItem("savestream:pending-verification-email");
    if (pending) setEmail(pending);
  }, []);

  useEffect(() => {
    if (!token || isDemoMode || verificationStarted.current) return;
    verificationStarted.current = true;
    let cancelled = false;

    void authApi
      .verifyEmail(token)
      .then(async () => {
        if (cancelled) return;
        if (typeof window !== "undefined") {
          window.sessionStorage.removeItem("savestream:pending-verification-email");
        }
        track("email_verified");
        await navigate({ to: "/verify-email/success", replace: true });
      })
      .catch((verifyError) => {
        if (!cancelled) {
          setError(authErrorMessage(verifyError));
          setVerifying(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [navigate, token]);

  useEffect(() => {
    if (!cooldown) return;
    const timer = setTimeout(() => setCooldown((current) => current - 1), 1000);
    return () => clearTimeout(timer);
  }, [cooldown]);

  if (verifying) {
    return (
      <AuthCardLayout width="lg">
        <div className="flex flex-col items-center gap-4 text-center">
          <IconTile>
            <span className="size-7 animate-spin rounded-full border-[3px] border-current border-t-transparent" />
          </IconTile>
          <h1 className="text-[30px] font-extrabold tracking-[-0.03em]">
            {t("Verifying your email")}
          </h1>
          <p className="text-muted-foreground">
            {t("Please keep this page open while we activate your account.")}
          </p>
        </div>
      </AuthCardLayout>
    );
  }

  return (
    <AuthCardLayout
      width="lg"
      topRight={
        <Link to="/sign-in" className="text-sm font-semibold text-accent-ink">
          {t("Back to sign in")}
        </Link>
      }
    >
      <div className="flex flex-col items-center gap-[22px] text-center">
        <IconTile>
          <Mail className="size-7" />
        </IconTile>
        <div className="flex flex-col items-center gap-2">
          <h1 className="text-[30px] font-extrabold tracking-[-0.03em]">{t("Check your inbox")}</h1>
          <p className="text-muted-foreground">
            We sent a verification link to{" "}
            {email ? <b className="text-foreground">{email}</b> : "your email"}. Open it on this
            device to activate your account.{" "}
            <Link to="/sign-up" className="font-semibold text-accent-ink">
              {t("Wrong email?")}
            </Link>
          </p>
        </div>
        {error && (
          <p
            role="alert"
            className="w-full rounded-xl border border-destructive/25 bg-destructive/10 px-4 py-3 text-left text-sm text-destructive"
          >
            {error}
          </p>
        )}
        <div className="flex flex-col items-center gap-1 text-sm">
          <span className="text-muted-foreground">{t("Didn’t get it? Check spam, or")}</span>
          <span className="flex items-center gap-2">
            <Button
              size="sm"
              variant="ghost"
              className="text-accent-ink"
              disabled={cooldown > 0 || (!isDemoMode && !email)}
              onClick={() => {
                if (isDemoMode) {
                  setCooldown(30);
                  setSent(true);
                  return;
                }
                if (!email) return;
                setError(null);
                void authApi
                  .resendVerification(email)
                  .then(() => {
                    setCooldown(30);
                    setSent(true);
                  })
                  .catch((resendError) => setError(authErrorMessage(resendError)));
              }}
            >
              {t("Resend link")}
            </Button>
            {cooldown > 0 && (
              <span className="font-mono text-xs text-muted-foreground">
                available in 0:{String(cooldown).padStart(2, "0")}
              </span>
            )}
          </span>
        </div>
        {sent && (
          <div className="flex w-full items-center gap-2.5 rounded-xl border border-success/25 bg-success-subtle px-4 py-3 text-left text-sm">
            <Check className="size-4 shrink-0 text-success" />
            New link sent. It expires in {ONE_TIME_LINK_MINUTES} minutes.
          </div>
        )}
        {isDemoMode && (
          <div className="w-full rounded-md border border-dashed p-3 text-xs text-muted-foreground">
            Prototype:{" "}
            <Link to="/verify-email/success" className="text-primary underline underline-offset-4">
              open verification link
            </Link>{" "}
            ·{" "}
            <Link to="/auth/error" className="text-primary underline underline-offset-4">
              open expired link
            </Link>
          </div>
        )}
      </div>
    </AuthCardLayout>
  );
}

export function VerifyEmailSuccessPage() {
  const { t } = usePreferences();
  const { status } = useAuth();
  const trialLabel = useTrialMinutesLabel();
  const { query } = usePublicPricingData();
  const minutes = trialMinutes(query.data);
  const signedIn = isDemoMode || status === "authenticated";
  return (
    <AuthCardLayout width="lg">
      <div className="flex flex-col items-center gap-[22px] text-center">
        <IconTile tone="ok" size="xl">
          <Check className="size-8" />
        </IconTile>
        <div className="flex flex-col items-center gap-2">
          <h1 className="text-[30px] font-extrabold tracking-[-0.03em]">{t("Email verified")}</h1>
          <p className="text-muted-foreground">
            {t("Your email is confirmed and your account is ready.")}
          </p>
        </div>
        {trialLabel && (
          <div className="flex w-full items-center gap-3.5 rounded-2xl border bg-surface-2 px-[18px] py-4 text-left">
            <IconTile size="md">
              <Gift className="size-5" />
            </IconTile>
            <div className="flex min-w-0 flex-1 flex-col gap-0.5">
              <b>{trialLabel} added</b>
              <span className="text-sm text-muted-foreground">
                Free trial credits for your account. No card needed.
              </span>
            </div>
            {minutes && (
              <b className="whitespace-nowrap font-mono text-xl text-accent-ink">+{minutes} min</b>
            )}
          </div>
        )}
        {signedIn ? (
          <>
            <Button size="lg" className="w-full" asChild>
              <Link to="/onboarding">{t("Add your first channel")}</Link>
            </Button>
            <Link to="/overview" className="text-sm font-semibold text-accent-ink">
              {t("Go to dashboard instead")}
            </Link>
          </>
        ) : (
          <>
            <Button size="lg" className="w-full" asChild>
              <Link to="/sign-in">{t("Sign in to add your first channel")}</Link>
            </Button>
          </>
        )}
      </div>
    </AuthCardLayout>
  );
}

const linkErrors = {
  expired: [
    "This link has expired",
    `Verification and reset links work for ${ONE_TIME_LINK_MINUTES} minutes and only once. Request a new one to continue.`,
    "LINK_EXPIRED",
  ],
  invalid: [
    "This link isn’t valid",
    "The link may have been used already or copied incorrectly. Request a new link or sign in.",
    "LINK_INVALID",
  ],
} as const;

type SocialReason = "cancelled" | "failed" | "email_in_use";

function socialError(provider: "google" | "apple", reason: SocialReason) {
  const name = provider === "apple" ? "Apple" : "Google";
  return {
    cancelled: [
      "Sign-in was cancelled",
      `You closed the ${name} window before finishing. Nothing was changed — try again or use your email.`,
      "OAUTH_CANCELLED",
    ],
    failed: [
      `We couldn’t sign you in with ${name}`,
      `${name} didn’t confirm your account. This is usually temporary — try again in a moment.`,
      "OAUTH_PROVIDER_ERROR",
    ],
    email_in_use: [
      "This email already has a password",
      `The email on your ${name} account is registered with email and password. Sign in with your password instead.`,
      "OAUTH_EMAIL_CONFLICT",
    ],
  }[reason];
}

/**
 * /auth/error — Google/Apple sign-in errors (`?provider=google|apple&reason=
 * cancelled|failed|email_in_use`) and expired or invalid email links
 * (`?reason=expired|invalid`, the default).
 */
export function AuthErrorPage() {
  const { t } = usePreferences();
  const search = useRouterState({ select: (state) => state.location.search }) as Record<
    string,
    unknown
  >;
  const [demoKind, setDemoKind] = useState<keyof typeof linkErrors>("expired");
  const provider =
    search["provider"] === "apple" ? "apple" : search["provider"] === "google" ? "google" : null;
  const reasonParam = String(search["reason"] ?? "");
  const social =
    provider && ["cancelled", "failed", "email_in_use"].includes(reasonParam)
      ? (reasonParam as SocialReason)
      : provider
        ? "failed"
        : null;
  const linkKind: keyof typeof linkErrors = isDemoMode
    ? demoKind
    : reasonParam === "invalid"
      ? "invalid"
      : "expired";
  const [title, body, code] =
    provider && social ? socialError(provider, social) : linkErrors[linkKind];

  return (
    <AuthCardLayout
      width="lg"
      topRight={
        <Link to="/sign-in" className="text-sm font-semibold text-accent-ink">
          {t("Sign in")}
        </Link>
      }
    >
      {isDemoMode && !provider && (
        <PrototypeStateBar
          value={demoKind}
          onChange={setDemoKind}
          options={[
            { value: "expired", label: "Expired" },
            { value: "invalid", label: "Invalid" },
          ]}
        />
      )}
      <div className="flex flex-col items-center gap-[22px] text-center">
        <IconTile tone="err" size="xl">
          {provider ? <AlertCircle className="size-8" /> : <Link2Off className="size-8" />}
        </IconTile>
        <div className="flex flex-col items-center gap-2">
          <h1 className="text-[30px] font-extrabold tracking-[-0.03em]">{t(title)}</h1>
          <p className="text-muted-foreground">{t(body)}</p>
        </div>
        {provider && social !== "email_in_use" ? (
          <SocialButton
            provider={provider}
            label={`Try ${provider === "apple" ? "Apple" : "Google"} again`}
            onClick={() => {
              window.location.assign("/sign-in");
            }}
            className="w-full"
          />
        ) : null}
        {provider ? (
          <Button
            size="lg"
            variant={social === "email_in_use" ? "default" : "outline"}
            className="w-full"
            asChild
          >
            <Link to="/sign-in">{t("Use email instead")}</Link>
          </Button>
        ) : (
          <>
            <Button size="lg" className="w-full" asChild>
              <Link to="/forgot-password">{t("Reset your password")}</Link>
            </Button>
            <Button size="lg" variant="outline" className="w-full" asChild>
              <Link to="/verify-email" search={{ token: "" }}>
                {t("Request a new verification link")}
              </Link>
            </Button>
          </>
        )}
        <span className="font-mono text-xs text-muted-foreground">Error code: {code}</span>
      </div>
    </AuthCardLayout>
  );
}

/* ---------------- Settings ---------------- */
type SettingsSectionId = "account" | "notifications" | "security";
const settingsTabs = [
  { id: "account", to: "/settings/account", label: "Account" },
  { id: "notifications", to: "/settings/notifications", label: "Notifications" },
  { id: "security", to: "/settings/security", label: "Security" },
] as const;
export function SettingsPage({ section = "account" }: { section?: SettingsSectionId }) {
  const { t } = usePreferences();
  return (
    <AppShell>
      <div className="flex max-w-[960px] flex-col gap-5">
        <h1 className="text-[32px] font-extrabold tracking-tight">Settings</h1>
        <nav aria-label="Settings sections" className="flex gap-1 overflow-x-auto border-b">
          {settingsTabs.map((tab) => (
            <Link
              key={tab.id}
              to={tab.to}
              aria-current={section === tab.id ? "page" : undefined}
              className={cn(
                "-mb-px inline-flex h-11 shrink-0 items-center border-b-2 border-transparent px-3 text-sm font-bold text-muted-foreground hover:text-foreground",
                section === tab.id && "border-primary text-foreground",
              )}
            >
              {t(tab.label)}
            </Link>
          ))}
        </nav>
        {section === "account" && <AccountSettings />}
        {section === "notifications" && <NotificationSettings />}
        {section === "security" && <SecuritySettings />}
      </div>
    </AppShell>
  );
}
function Section({
  title,
  body,
  children,
  danger,
  action,
}: {
  title: string;
  body: ReactNode;
  children: ReactNode;
  danger?: boolean;
  action?: ReactNode;
}) {
  const { t } = usePreferences();
  return (
    <section
      className={cn(
        "overflow-hidden rounded-[18px] border bg-surface",
        danger && "border-destructive/35",
      )}
    >
      <div className="flex flex-wrap items-start justify-between gap-3 border-b px-5 py-4 sm:px-6">
        <div className="space-y-1">
          <h2 className={cn("text-[17px] font-bold", danger && "text-destructive")}>{t(title)}</h2>
          <p className="text-sm text-muted-foreground">
            {typeof body === "string" ? t(body) : body}
          </p>
        </div>
        {action}
      </div>
      <div className="space-y-4 px-5 py-5 sm:px-6">{children}</div>
    </section>
  );
}
function LabeledInput({
  id,
  label,
  ...p
}: { id: string; label: string } & React.ComponentProps<typeof Input>) {
  const { t } = usePreferences();
  return (
    <div>
      <label htmlFor={id} className="block text-sm font-medium">
        {t(label)}
      </label>
      <Input id={id} className="mt-2" {...p} />
    </div>
  );
}
function AccountSettings() {
  return isDemoMode ? <DemoAccountSettings /> : <ProductionAccountSettings />;
}

function ProductionAccountSettings() {
  const { t } = usePreferences();
  const navigate = useNavigate();
  const { refreshSession } = useAuth();
  const { query, state } = useCurrentUserData();
  const updateProfile = useUpdateProfileMutation();
  const exportAccount = useExportAccountMutation();
  const deleteAccount = useDeleteAccountMutation();
  const resendVerification = useResendVerificationMutation();
  const [name, setName] = useState("");
  const [del, setDel] = useState(false);
  const [confirmText, setConfirmText] = useState("");

  useEffect(() => {
    if (!query.data) return;
    setName(query.data.display_name ?? "");
  }, [query.data]);

  if (state.kind === "loading") {
    return <div className="h-64 animate-pulse rounded-lg border bg-muted" aria-busy="true" />;
  }

  if (state.kind === "error" || !query.data) {
    return (
      <ErrorState
        title="Could not load account settings"
        body="SaveStream could not load your current profile."
        onRetry={() => query.refetch()}
      />
    );
  }

  const profile = query.data;
  const dirty = name !== (profile.display_name ?? "");
  const initials = (profile.display_name || profile.email)
    .split(/[\s@._-]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");

  const save = () => {
    void updateProfile
      .mutateAsync({
        // English-only product: the stored locale is no longer edited.
        display_name: name.trim() || null,
      })
      .then(async () => {
        await refreshSession();
        toast.success(t("Changes saved"));
      })
      .catch((error) =>
        toast.error("Could not save profile", {
          description: accountActionErrorMessage(error),
        }),
      );
  };

  const downloadExport = () => {
    void exportAccount
      .mutateAsync()
      .then((payload) => {
        const blob = new Blob([JSON.stringify(payload, null, 2)], {
          type: "application/json",
        });
        const url = URL.createObjectURL(blob);
        const anchor = document.createElement("a");
        anchor.href = url;
        anchor.download = "savestream-account-export.json";
        anchor.click();
        window.setTimeout(() => URL.revokeObjectURL(url), 0);
        toast.success("Account export downloaded");
      })
      .catch((error) =>
        toast.error("Could not export account data", {
          description: accountActionErrorMessage(error),
        }),
      );
  };

  return (
    <>
      <Section title="Profile" body="How you appear in SaveStream and on order records.">
        <div className="flex items-center gap-4">
          <span className="grid size-16 place-items-center rounded-full bg-gradient-to-br from-avatar-one to-avatar-one-end text-lg font-extrabold text-avatar-foreground">
            {initials || "SS"}
          </span>
          <div className="min-w-0">
            <p className="truncate font-bold">{profile.display_name || profile.email}</p>
            <p className="text-sm text-muted-foreground">
              Member since{" "}
              {new Date(profile.created_at).toLocaleDateString("en", {
                month: "short",
                year: "numeric",
              })}
            </p>
          </div>
        </div>
        <div className="grid gap-4 [grid-template-columns:repeat(auto-fit,minmax(min(260px,100%),1fr))]">
          <LabeledInput
            id="acc-name"
            label="Display name"
            value={name}
            maxLength={160}
            onChange={(event) => setName(event.target.value)}
          />
          <div>
            <label htmlFor="acc-email" className="block text-sm font-medium">
              Email
            </label>
            <div className="relative mt-2">
              <Input
                id="acc-email"
                type="email"
                value={profile.email}
                readOnly
                disabled
                className="pr-24"
              />
              <span
                className={cn(
                  "absolute right-2.5 top-1/2 -translate-y-1/2 rounded-full px-2 py-0.5 text-xs font-bold",
                  profile.email_verified
                    ? "bg-success-subtle text-success"
                    : "bg-warning-subtle text-warning-foreground",
                )}
              >
                {profile.email_verified ? "Verified" : "Not verified"}
              </span>
            </div>
            <p className="mt-1.5 text-xs text-muted-foreground">
              To change your email address, contact support@savestream.online.
            </p>
          </div>
        </div>
        {!profile.email_verified && (
          <StateBanner
            tone="warning"
            icon={Mail}
            title="Verify your email"
            body="Your account email has not been verified yet. You can request a fresh verification message."
            action={
              <Button
                size="sm"
                variant="outline"
                disabled={resendVerification.isPending}
                onClick={() => {
                  void resendVerification
                    .mutateAsync(profile.email)
                    .then(() => toast.success("Verification email requested"))
                    .catch((error) =>
                      toast.error("Could not resend verification", {
                        description: accountActionErrorMessage(error),
                      }),
                    );
                }}
              >
                {resendVerification.isPending ? "Sending…" : "Resend verification"}
              </Button>
            }
          />
        )}
        <div className="flex justify-end gap-2.5">
          <Button
            variant="ghost"
            disabled={!dirty}
            onClick={() => setName(profile.display_name ?? "")}
          >
            Cancel
          </Button>
          <Button onClick={save} disabled={!dirty || updateProfile.isPending}>
            {updateProfile.isPending ? "Saving…" : t("Save changes")}
          </Button>
        </div>
      </Section>

      <Section title="Sign-in methods" body="Ways you can sign in to SaveStream.">
        <div className="-mx-5 -my-5 divide-y sm:-mx-6">
          <div className="flex items-center gap-3 px-5 py-3.5 sm:px-6">
            <KeyRound className="size-5 text-muted-foreground" />
            <span className="min-w-0 flex-1">
              <b className="block text-sm">Email & password</b>
              <span className="text-xs text-muted-foreground">{profile.email}</span>
            </span>
            <Button asChild size="sm" variant="outline">
              <Link to="/settings/security">Change</Link>
            </Button>
          </div>
          {!firebaseSocialConfigured && (
            <div className="flex items-center gap-3 px-5 py-3.5 sm:px-6">
              <GoogleIcon />
              <span className="min-w-0 flex-1">
                <b className="block text-sm">Google & Apple</b>
                <span className="text-xs text-muted-foreground">Coming soon.</span>
              </span>
            </div>
          )}
          {(firebaseSocialConfigured ? (["Google", "Apple"] as const) : []).map((provider) => (
            <div key={provider} className="flex items-center gap-3 px-5 py-3.5 sm:px-6">
              {provider === "Google" ? <GoogleIcon /> : <AppleIcon />}
              <span className="min-w-0 flex-1">
                <b className="block text-sm">{provider}</b>
                <span className="text-xs text-muted-foreground">
                  Available on the sign-in page. If it uses this email, you’ll confirm your password
                  once to link it.
                </span>
              </span>
            </div>
          ))}
        </div>
      </Section>

      <Section
        title="Export your data"
        body="Download the account export returned by SaveStream as JSON. Recordings themselves are downloaded separately."
      >
        <Button
          variant="outline"
          className="w-fit"
          disabled={exportAccount.isPending}
          onClick={downloadExport}
        >
          <Download />
          {exportAccount.isPending ? "Preparing export…" : "Download data export"}
        </Button>
      </Section>

      <Section
        danger
        title="Delete account"
        body="Request account deletion. SaveStream immediately disables the account and revokes all sessions, then processes deletion according to the server retention policy."
      >
        <Button variant="destructive" className="w-fit" onClick={() => setDel(true)}>
          <Trash2 />
          {t("Delete account")}
        </Button>
      </Section>

      <ConfirmDialog
        destructive
        open={del}
        onOpenChange={(open) => {
          setDel(open);
          if (!open) setConfirmText("");
        }}
        title="Request account deletion?"
        body="Your account is closed immediately and you are signed out everywhere. Your recordings and personal data are then deleted. This cannot be undone."
        confirmLabel={deleteAccount.isPending ? "Requesting…" : "Delete account"}
        confirmDisabled={confirmText !== "DELETE" || deleteAccount.isPending}
        onConfirm={() => {
          void deleteAccount
            .mutateAsync()
            .then(async () => {
              setDel(false);
              toast.success("Account deletion requested");
              await refreshSession();
              await navigate({ to: "/", replace: true });
            })
            .catch((error) =>
              toast.error("Could not request account deletion", {
                description: accountActionErrorMessage(error),
              }),
            );
        }}
      >
        <div>
          <label htmlFor="confirm-delete" className="text-sm">
            Type <b className="font-mono">DELETE</b> to confirm
          </label>
          <Input
            id="confirm-delete"
            className="mt-2"
            value={confirmText}
            onChange={(event) => setConfirmText(event.target.value)}
            autoComplete="off"
          />
        </div>
      </ConfirmDialog>
    </>
  );
}

function DemoAccountSettings() {
  const { t } = usePreferences();
  const navigate = useNavigate();
  const [name, setName] = useState(user.name);
  const [email, setEmail] = useState(user.email);
  const [pending, setPending] = useState<string | null>(null);
  const [del, setDel] = useState(false);
  const [confirmText, setConfirmText] = useState("");
  const dirty = name !== user.name || email !== (pending ?? user.email);
  const save = () => {
    if (email !== user.email && email !== pending) {
      setPending(email);
      toast.success("Verification email sent", {
        description: `Confirm ${email} to finish changing your email.`,
      });
    } else toast.success(t("Changes saved"));
  };
  return (
    <>
      <Section title="Profile" body="Your name and email are used for sign in and notifications.">
        <div className="flex items-center gap-4">
          <span className="grid size-14 place-items-center rounded-full bg-primary text-sm font-semibold text-primary-foreground">
            {user.initials}
          </span>
          <div className="flex gap-2">
            <Button
              variant="outline"
              onClick={() => toast("Image upload is mocked in this prototype")}
            >
              {t("Change image")}
            </Button>
            <Button variant="ghost" onClick={() => toast("Profile image removed")}>
              {t("Remove")}
            </Button>
          </div>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <LabeledInput
            id="acc-name"
            label="Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
          <LabeledInput
            id="acc-email"
            label="Email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </div>
        {pending && (
          <StateBanner
            tone="info"
            icon={Mail}
            title="Verify your new email"
            body={
              <>
                We sent a link to <b className="text-foreground">{pending}</b>. Until you confirm
                it, you’ll keep signing in with {user.email}.
              </>
            }
            action={
              <div className="flex gap-2">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => toast.success("Verification email resent")}
                >
                  Resend
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => {
                    setPending(null);
                    setEmail(user.email);
                  }}
                >
                  Cancel change
                </Button>
              </div>
            }
          />
        )}
        <Button onClick={save} disabled={!dirty}>
          {t("Save changes")}
        </Button>
      </Section>
      <Section
        title="Export your data"
        body="Download your account details, channel list, and recording metadata as a JSON file. Videos are downloaded separately from Recordings."
      >
        <Button
          variant="outline"
          className="w-fit"
          onClick={() =>
            toast.success(t("Export requested"), {
              description: "We’ll email you a download link when it’s ready.",
            })
          }
        >
          <Download />
          {t("Request data export")}
        </Button>
      </Section>
      <Section
        danger
        title="Delete account"
        body="Permanently delete your account, stop all monitoring, and remove every recording from cloud storage. This can’t be undone."
      >
        <Button variant="destructive" className="w-fit" onClick={() => setDel(true)}>
          <Trash2 />
          {t("Delete account")}
        </Button>
      </Section>
      <ConfirmDialog
        destructive
        open={del}
        onOpenChange={(o) => {
          setDel(o);
          if (!o) setConfirmText("");
        }}
        title="Delete your account?"
        body="All channels, recordings, and account data will be removed. Purchased credits are forfeited when the account is deleted; billing records may be retained where required."
        confirmLabel="Delete account"
        confirmDisabled={confirmText !== "DELETE"}
        onConfirm={() => {
          setDel(false);
          toast.success(t("Account deleted"));
          navigate({ to: "/" });
        }}
      >
        <div>
          <label htmlFor="confirm-delete" className="text-sm">
            Type <b className="font-mono">DELETE</b> to confirm
          </label>
          <Input
            id="confirm-delete"
            className="mt-2"
            value={confirmText}
            onChange={(e) => setConfirmText(e.target.value)}
            autoComplete="off"
          />
        </div>
      </ConfirmDialog>
    </>
  );
}
const notifPrefs = [
  ["started", "Recording started", "When a monitored channel goes live and recording begins."],
  ["completed", "Recording completed", "When a recording is processed and ready to watch."],
  ["failed", "Recording failed", "When a recording stops unexpectedly or can’t be processed."],
  ["quota", "Credit warning", "When your cloud credits are running low or reach zero."],
  [
    "expiry",
    "Retention / expiration warning",
    "Before a recording is removed at the end of its retention period.",
  ],
] as const;
function NotificationSettings() {
  return isDemoMode ? <DemoNotificationSettings /> : <ProductionNotificationSettings />;
}

function ProductionNotificationSettings() {
  const preferences = useNotificationPreferencesData();
  const updatePreferences = useUpdateNotificationPreferencesMutation();
  const [draft, setDraft] = useState<{
    recording_started: boolean;
    recording_ready: boolean;
    recording_failed: boolean;
  } | null>(null);

  useEffect(() => {
    if (!preferences.data) return;
    setDraft({
      recording_started: preferences.data.recording_started,
      recording_ready: preferences.data.recording_ready,
      recording_failed: preferences.data.recording_failed,
    });
  }, [preferences.data]);

  if (preferences.isPending) {
    return <div className="h-56 animate-pulse rounded-lg border bg-muted" aria-busy="true" />;
  }

  if (preferences.isError || !preferences.data) {
    return (
      <ErrorState
        title="Could not load notification preferences"
        body="Please try again in a moment."
        onRetry={() => preferences.refetch()}
      />
    );
  }

  const current = draft ?? {
    recording_started: preferences.data.recording_started,
    recording_ready: preferences.data.recording_ready,
    recording_failed: preferences.data.recording_failed,
  };
  const dirty =
    current.recording_started !== preferences.data.recording_started ||
    current.recording_ready !== preferences.data.recording_ready ||
    current.recording_failed !== preferences.data.recording_failed;
  const rows = [
    [
      "recording_started",
      "Recording started",
      "Create an in-app notification when a recording starts.",
    ],
    [
      "recording_ready",
      "Recording ready",
      "Create an in-app notification when a recording finishes successfully.",
    ],
    [
      "recording_failed",
      "Recording ended",
      "Create an in-app notification when a recording fails or stops early.",
    ],
  ] as const;

  return (
    <>
      <Section
        title="In-app notification preferences"
        body="These preferences apply on every device you sign in to."
      >
        <div>
          {rows.map(([key, label, description]) => (
            <div
              key={key}
              className="flex items-center justify-between gap-4 border-b py-4 last:border-0"
            >
              <div>
                <label htmlFor={`prod-np-${key}`} className="text-sm font-medium">
                  {label}
                </label>
                <p className="text-xs text-muted-foreground">{description}</p>
              </div>
              <Switch
                id={`prod-np-${key}`}
                checked={current[key]}
                onCheckedChange={(checked) =>
                  setDraft((previous) => ({
                    ...(previous ?? current),
                    [key]: checked,
                  }))
                }
              />
            </div>
          ))}
        </div>
        <Button
          disabled={!dirty || updatePreferences.isPending}
          onClick={() => {
            void updatePreferences
              .mutateAsync(current)
              .then((saved) => {
                setDraft({
                  recording_started: saved.recording_started,
                  recording_ready: saved.recording_ready,
                  recording_failed: saved.recording_failed,
                });
                toast.success("Notification preferences saved");
              })
              .catch(() => toast.error("Could not save notification preferences"));
          }}
        >
          {updatePreferences.isPending ? "Saving…" : "Save preferences"}
        </Button>
      </Section>
      <EmailNotificationSettings preferences={preferences.data} />
    </>
  );
}

const EMAIL_ROWS: readonly [EmailPreferenceKey, string, string][] = [
  [
    "email_creator_live",
    "Channel went LIVE",
    "When a channel you monitor goes live (at most one email per channel every 6 hours).",
  ],
  [
    "email_recording_ready",
    "Recording ready",
    "When a recording is saved and ready to watch or download.",
  ],
  [
    "email_recording_failed",
    "Recording failed or missed",
    "When a recording stops early or a LIVE is missed.",
  ],
  [
    "email_recording_expiring",
    "Recording expiring soon",
    "About 24 hours before a recording is deleted from cloud storage.",
  ],
  [
    "email_credits_low",
    "Credits running low",
    "Once a day at most, when an hour or less of cloud recording is left.",
  ],
  [
    "email_credits_exhausted",
    "Out of credits",
    "When your cloud recording credits run out and auto-record pauses.",
  ],
];

function EmailNotificationSettings({
  preferences,
}: {
  preferences: NotificationPreferencesResponse;
}) {
  const updatePreferences = useUpdateNotificationPreferencesMutation();
  const [pending, setPending] = useState<EmailPreferenceKey | null>(null);
  const toggle = (key: EmailPreferenceKey, checked: boolean) => {
    setPending(key);
    void updatePreferences
      .mutateAsync({ [key]: checked })
      .then(() => toast.success(checked ? "Email turned on" : "Email turned off"))
      .catch(() => toast.error("Could not save email preferences"))
      .finally(() => setPending(null));
  };
  return (
    <Section
      title="Email notifications"
      body="Sent to your account email. In-app notifications are not affected. Every email has a one-click unsubscribe link."
    >
      <div>
        {EMAIL_ROWS.map(([key, label, description]) => (
          <div
            key={key}
            className="flex items-center justify-between gap-4 border-b py-4 last:border-0"
          >
            <div>
              <label htmlFor={`email-np-${key}`} className="text-sm font-medium">
                {label}
              </label>
              <p className="text-xs text-muted-foreground">{description}</p>
            </div>
            <Switch
              id={`email-np-${key}`}
              checked={preferences[key] ?? true}
              disabled={pending === key}
              onCheckedChange={(checked) => toggle(key, checked)}
            />
          </div>
        ))}
      </div>
      <StateBanner
        tone="info"
        icon={Mail}
        title="Required account emails"
        body="Account emails such as email verification and password resets are always sent and can’t be turned off. To avoid inbox floods we send at most 6 notification emails an hour and 20 a day; anything over that stays in the app."
      />
    </Section>
  );
}

function DemoNotificationSettings() {
  const { t } = usePreferences();
  const initial = { started: false, completed: true, failed: true, quota: true, expiry: true };
  const [saved, setSaved] = useState(initial);
  const [prefs, setPrefs] = useState(initial);
  const [justSaved, setJustSaved] = useState(false);
  const dirty = JSON.stringify(saved) !== JSON.stringify(prefs);
  return (
    <Section
      title="Email notifications"
      body={`Sent to ${user.email}. In-app notifications are always on.`}
    >
      <div>
        {notifPrefs.map(([k, label, description]) => (
          <div
            key={k}
            className="flex items-center justify-between gap-4 border-b py-4 last:border-0"
          >
            <div>
              <label htmlFor={`np-${k}`} className="text-sm font-medium">
                {t(label)}
              </label>
              <p className="text-xs text-muted-foreground">{t(description)}</p>
            </div>
            <Switch
              id={`np-${k}`}
              checked={prefs[k]}
              onCheckedChange={(v) => {
                setPrefs((p) => ({ ...p, [k]: v }));
                setJustSaved(false);
              }}
            />
          </div>
        ))}
      </div>
      <div className="flex items-center gap-3">
        <Button
          disabled={!dirty}
          onClick={() => {
            setSaved(prefs);
            setJustSaved(true);
            toast.success(t("Notification preferences saved"));
          }}
        >
          {t("Save preferences")}
        </Button>
        {justSaved && !dirty && (
          <span className="flex items-center gap-1 text-sm text-success">
            <CheckCircle2 className="size-4" />
            {t("Saved")}
          </span>
        )}
        {dirty && <span className="text-xs text-muted-foreground">{t("Unsaved changes")}</span>}
      </div>
    </Section>
  );
}
function SecuritySettings() {
  return isDemoMode ? <DemoSecuritySettings /> : <ProductionSecuritySettings />;
}

function ProductionSecuritySettings() {
  const { t } = usePreferences();
  const navigate = useNavigate();
  const { signOutEverywhere } = useAuth();
  const { query: profileQuery, state: profileState } = useCurrentUserData();
  const { query: sessionsQuery, state: sessionsState } = useSessionsData();
  const revokeSession = useRevokeSessionMutation();
  const resetPassword = useRequestPasswordResetMutation();
  const [signOutAll, setSignOutAll] = useState(false);

  if (profileState.kind === "loading" || sessionsState.kind === "loading") {
    return <div className="h-64 animate-pulse rounded-lg border bg-muted" aria-busy="true" />;
  }

  if (profileState.kind === "error" || !profileQuery.data) {
    return (
      <ErrorState
        title="Could not load security settings"
        body="SaveStream could not load your account security state."
        onRetry={() => profileQuery.refetch()}
      />
    );
  }

  const profile = profileQuery.data;
  const sessions = sessionsQuery.data?.items ?? [];

  return (
    <>
      <Section
        title="Password"
        body="To change your password, we’ll email you a secure reset link."
      >
        <Button
          className="w-fit"
          variant="outline"
          disabled={resetPassword.isPending}
          onClick={() => {
            void resetPassword
              .mutateAsync(profile.email)
              .then(() =>
                toast.success("Password reset email requested", {
                  description: profile.email,
                }),
              )
              .catch((error) =>
                toast.error("Could not request password reset", {
                  description: accountActionErrorMessage(error),
                }),
              );
          }}
        >
          <Mail />
          {resetPassword.isPending ? "Sending…" : "Email password reset link"}
        </Button>
      </Section>

      <Section
        title="Active sessions"
        body={`Devices currently signed in to your account (${sessions.length}).`}
        action={
          <Button
            variant="ghost"
            className="text-destructive hover:bg-destructive/10 hover:text-destructive"
            onClick={() => setSignOutAll(true)}
          >
            Sign out everywhere
          </Button>
        }
      >
        {sessionsState.kind === "error" ? (
          <ErrorState
            title="Could not load sessions"
            body="SaveStream could not load active sessions."
            onRetry={() => sessionsQuery.refetch()}
          />
        ) : sessions.length ? (
          <div className="-mx-5 overflow-x-auto sm:-mx-6">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-y bg-surface-2 text-left text-[11px] font-bold uppercase tracking-[.06em] text-muted-foreground">
                  <th scope="col" className="px-5 py-2.5 sm:px-6">
                    Device
                  </th>
                  <th scope="col" className="px-4 py-2.5">
                    IP
                  </th>
                  <th scope="col" className="px-4 py-2.5">
                    Last active
                  </th>
                  <th scope="col" className="px-5 py-2.5 sm:px-6">
                    <span className="sr-only">Action</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {sessions.map((session) => (
                  <tr key={session.id} className="border-b last:border-b-0">
                    <td className="px-5 py-3 sm:px-6">
                      <div className="flex items-center gap-3">
                        <span className="grid size-9 shrink-0 place-items-center rounded-[10px] bg-surface-2">
                          {/Mobile|iPhone|Android/i.test(session.user_agent ?? "") ? (
                            <Smartphone className="size-[18px]" />
                          ) : (
                            <Monitor className="size-[18px]" />
                          )}
                        </span>
                        <span className="min-w-0">
                          <b className="block">{describeUserAgent(session.user_agent)}</b>
                          <span className="text-xs text-muted-foreground">
                            Signed in{" "}
                            {new Date(session.created_at).toLocaleDateString("en", {
                              month: "short",
                              day: "numeric",
                            })}
                          </span>
                        </span>
                        {session.current && (
                          <span className="rounded-full bg-success-subtle px-2 py-0.5 text-xs font-bold text-success">
                            {t("This device")}
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-muted-foreground">
                      {session.ip_hint || "—"}
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {new Date(session.last_seen_at).toLocaleString("en", {
                        month: "short",
                        day: "numeric",
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </td>
                    <td className="px-5 py-3 text-right sm:px-6">
                      {!session.current && (
                        <Button
                          size="sm"
                          variant="ghost"
                          disabled={revokeSession.isPending}
                          onClick={() => {
                            void revokeSession
                              .mutateAsync(session.id)
                              .then(() => toast.success("Session revoked"))
                              .catch((error) =>
                                toast.error("Could not revoke session", {
                                  description: accountActionErrorMessage(error),
                                }),
                              );
                          }}
                        >
                          Sign out
                        </Button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">No sessions were returned.</p>
        )}
      </Section>

      <ConfirmDialog
        open={signOutAll}
        onOpenChange={setSignOutAll}
        title="Sign out everywhere?"
        body="All SaveStream sessions, including this device, will be revoked. Recording and monitoring continue on the server."
        confirmLabel="Sign out everywhere"
        onConfirm={() => {
          void signOutEverywhere()
            .then(async () => {
              setSignOutAll(false);
              await navigate({ to: "/sign-in", replace: true });
            })
            .catch((error) =>
              toast.error("Could not sign out everywhere", {
                description: accountActionErrorMessage(error),
              }),
            );
        }}
      />
    </>
  );
}

function DemoSecuritySettings() {
  const { t } = usePreferences();
  const [cur, setCur] = useState("");
  const [pw, setPw] = useState("");
  const [pw2, setPw2] = useState("");
  const [list, setList] = useState(seedSessions);
  const [signOutAll, setSignOutAll] = useState(false);
  const pwError = pw2 && pw !== pw2 ? "Passwords don’t match." : null;
  return (
    <>
      <Section title="Change password" body="Use a strong password you don’t use anywhere else.">
        <PasswordField
          id="sec-cur"
          label="Current password"
          value={cur}
          onChange={setCur}
          autoComplete="current-password"
        />
        <PasswordField id="sec-new" label="New password" value={pw} onChange={setPw} showStrength />
        <PasswordField
          id="sec-confirm"
          label="Confirm new password"
          value={pw2}
          onChange={setPw2}
        />
        {pwError && (
          <p role="alert" className="text-sm text-destructive">
            {pwError}
          </p>
        )}
        <Button
          className="w-fit"
          disabled={!cur || pw.length < 8 || pw !== pw2}
          onClick={() => {
            setCur("");
            setPw("");
            setPw2("");
            toast.success(t("Password updated"));
          }}
        >
          {t("Update password")}
        </Button>
      </Section>
      <Section
        title="Active sessions"
        body={`Signed in on ${list.length} device${list.length === 1 ? "" : "s"}.`}
      >
        <ul className="divide-y border-y">
          {list.map((s) => (
            <li key={s.id} className="flex items-center gap-3 py-4">
              {s.device.includes("iPhone") ? (
                <Smartphone className="size-5 text-muted-foreground" />
              ) : (
                <Monitor className="size-5 text-muted-foreground" />
              )}
              <div className="min-w-0 flex-1">
                <p className="flex flex-wrap items-center gap-2 text-sm font-medium">
                  {s.device}
                  {s.current && (
                    <span className="rounded bg-success-subtle px-1.5 py-0.5 text-[10px] font-semibold uppercase text-success">
                      {t("This device")}
                    </span>
                  )}
                </p>
                <p className="text-xs text-muted-foreground">
                  {s.location} · {s.lastActive}
                </p>
              </div>
              {!s.current && (
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => {
                    setList((l) => l.filter((x) => x.id !== s.id));
                    toast.success("Session revoked", { description: s.device });
                  }}
                >
                  {t("Revoke")}
                </Button>
              )}
            </li>
          ))}
        </ul>
        <Button
          variant="outline"
          className="w-fit"
          disabled={list.length <= 1}
          onClick={() => setSignOutAll(true)}
        >
          {t("Sign out all other devices")}
        </Button>
      </Section>
      <Section title="Sign-in methods" body="How you can sign in to SaveStream.">
        <div className="flex items-center gap-3 rounded-md border p-3">
          <KeyRound className="size-4 text-muted-foreground" />
          <div className="flex-1">
            <p className="text-sm font-medium">{t("Email and password")}</p>
            <p className="text-xs text-muted-foreground">{user.email}</p>
          </div>
          <span className="text-xs font-medium text-success">{t("Connected")}</span>
        </div>
        <div className="flex items-center gap-3 rounded-md border p-3">
          <span className="grid size-4 place-items-center text-xs font-bold">G</span>
          <div className="flex-1">
            <p className="text-sm font-medium">{t("Google")}</p>
            <p className="text-xs text-muted-foreground">{t("Not connected")}</p>
          </div>
          <Button
            size="sm"
            variant="outline"
            onClick={() => toast("Google sign-in isn’t connected in this prototype.")}
          >
            {t("Connect")}
          </Button>
        </div>
      </Section>
      <ConfirmDialog
        open={signOutAll}
        onOpenChange={setSignOutAll}
        title="Sign out all other devices?"
        body="Every session except this one will be signed out immediately. Recording and monitoring are not affected."
        confirmLabel="Sign out devices"
        onConfirm={() => {
          setList((l) => l.filter((s) => s.current));
          setSignOutAll(false);
          toast.success("Signed out of all other devices");
        }}
      />
    </>
  );
}

/* ---------------- Notifications ---------------- */
export function NotificationsPage() {
  const { t } = usePreferences();
  const { notifications: list, query } = useNotificationFeed();
  const [filter, setFilter] = useState<"all" | "unread">("all");
  const shown = filter === "all" ? list : list.filter((n) => !n.read);
  const unread = list.filter((n) => !n.read).length;

  if (!isDemoMode && query.isPending) {
    return (
      <AppShell>
        <PageHeader title="Notifications" subtitle="Updates about your recordings." />
        <div className="h-64 max-w-3xl animate-pulse rounded-lg border bg-muted" aria-busy="true" />
      </AppShell>
    );
  }

  if (!isDemoMode && query.isError) {
    return (
      <AppShell>
        <PageHeader title="Notifications" subtitle="Updates about your recordings." />
        <ErrorState
          title="Could not load notifications"
          body="Please try again in a moment."
          onRetry={() => query.refetch()}
        />
      </AppShell>
    );
  }

  return (
    <AppShell>
      <div className="flex flex-col gap-5">
        <PageHeader
          title="Notifications"
          subtitle={unread ? `${unread} unread` : "You’re all caught up."}
          action={
            <Button
              variant="outline"
              disabled={!unread}
              onClick={() => {
                void notificationStore.markAllRead().then((ok) => {
                  if (ok) toast.success(t("All notifications marked as read"));
                  else toast.error("Could not mark notifications as read");
                });
              }}
            >
              {t("Mark all as read")}
            </Button>
          }
        />
        <div className="flex flex-wrap items-start gap-6">
          <section
            aria-label="Notification list"
            className="min-w-0 flex-[999_1_560px] overflow-hidden rounded-[18px] border bg-surface"
          >
            <div
              role="tablist"
              aria-label={t("Filter notifications")}
              className="flex gap-1 border-b px-4"
            >
              {(["all", "unread"] as const).map((f) => (
                <button
                  key={f}
                  type="button"
                  role="tab"
                  aria-selected={filter === f}
                  onClick={() => setFilter(f)}
                  className={cn(
                    "-mb-px inline-flex h-11 items-center gap-1.5 border-b-2 border-transparent px-3 text-sm font-bold text-muted-foreground",
                    filter === f && "border-primary text-foreground",
                  )}
                >
                  {f === "all" ? t("All") : `${t("Unread")} · ${unread}`}
                </button>
              ))}
            </div>
            {shown.length ? (
              shown.map((n) => <NotificationRow key={n.id} notification={n} />)
            ) : (
              <div className="flex flex-col items-center gap-2 px-6 py-14 text-center">
                <span className="grid size-14 place-items-center rounded-[18px] bg-success-subtle text-success">
                  <CheckCircle2 className="size-7" />
                </span>
                <b className="text-lg">
                  {filter === "unread" ? "You’re all caught up" : "No notifications yet"}
                </b>
                <p className="text-sm text-muted-foreground">
                  {filter === "unread"
                    ? "New alerts about your channels will show up here."
                    : "We’ll notify you when recordings start, finish, or need attention."}
                </p>
              </div>
            )}
          </section>
          <aside className="flex min-w-0 flex-[1_1_340px] flex-col gap-3">
            <NotificationSettings />
            <p className="px-1 text-xs text-muted-foreground">
              <b>Synced across devices</b> —{" "}
              {"Your notifications and read status are the same on every device."}{" "}
              {"New ones appear automatically while this page is open."}
            </p>
          </aside>
        </div>
      </div>
    </AppShell>
  );
}

const notificationTone: Record<string, { icon: typeof Bell; className: string; label: string }> = {
  recording_started: {
    icon: Radio,
    className: "bg-recording-subtle text-recording",
    label: "Recording started",
  },
  recording_ready: {
    icon: CheckCircle2,
    className: "bg-success-subtle text-success",
    label: "Recording ready",
  },
  recording_failed: {
    icon: AlertCircle,
    className: "bg-destructive/10 text-destructive",
    label: "Recording failed",
  },
  quota_warning: {
    icon: CreditCard,
    className: "bg-warning-subtle text-warning",
    label: "Credits",
  },
  cloud_minutes_exhausted: {
    icon: CreditCard,
    className: "bg-warning-subtle text-warning",
    label: "Credits",
  },
  credits_low: {
    icon: CreditCard,
    className: "bg-warning-subtle text-warning",
    label: "Credits",
  },
  channel_verification_needed: {
    icon: ShieldCheck,
    className: "bg-warning-subtle text-warning",
    label: "Verify channel",
  },
};

function NotificationRow({ notification: n }: { notification: NotificationModel }) {
  const tone = notificationTone[n.type] ?? {
    icon: Bell,
    className: "bg-surface-2 text-muted-foreground",
    label: "Update",
  };
  const Icon = tone.icon;
  return (
    <Link
      {...n.link}
      onClick={() => void notificationStore.markRead(n.id)}
      className={cn(
        "flex items-start gap-3.5 border-b px-5 py-4 last:border-b-0 hover:bg-surface-2 focus-visible:bg-surface-2 focus-visible:outline-none",
        !n.read && "bg-primary-subtle/50",
      )}
    >
      <span
        className={cn(
          "grid size-[38px] shrink-0 place-items-center rounded-[11px]",
          tone.className,
        )}
      >
        <Icon className="size-[18px]" />
      </span>
      <span className="min-w-0 flex-1 space-y-1">
        <span className="flex flex-wrap items-center gap-2">
          <b className="text-sm">{n.title}</b>
          <span className="rounded-full bg-surface-2 px-2 py-0.5 text-[11px] font-semibold text-muted-foreground">
            {tone.label}
          </span>
        </span>
        <span className="block text-sm text-muted-foreground">{n.body}</span>
        {n.link.to === "/billing" && (
          <span className="inline-flex h-8 items-center rounded-[10px] bg-primary px-3 text-xs font-bold text-primary-foreground">
            Buy a pack
          </span>
        )}
      </span>
      <span className="flex shrink-0 flex-col items-end gap-2">
        <span className="text-xs text-muted-foreground">{n.time}</span>
        {!n.read && <span aria-label="Unread" className="size-[9px] rounded-full bg-primary" />}
      </span>
    </Link>
  );
}

/* ---------------- Billing return pages ---------------- */
function PaymentResultCard({
  icon,
  tone,
  title,
  body,
  children,
}: {
  icon: ReactNode;
  tone: "ok" | "warn" | "err" | "muted" | "spin";
  title: string;
  body: ReactNode;
  children?: ReactNode;
}) {
  return (
    <AppShell>
      <div className="flex justify-center py-6 sm:py-12">
        <section className="flex w-full max-w-[560px] flex-col items-center gap-5 rounded-[24px] border bg-surface px-6 py-10 text-center sm:px-10">
          {tone === "spin" ? (
            <span
              aria-hidden="true"
              className="size-16 animate-spin rounded-full border-[5px] border-primary-subtle border-t-primary"
            />
          ) : (
            <span
              aria-hidden="true"
              className={cn(
                "grid size-[72px] place-items-center rounded-[22px]",
                tone === "ok" && "bg-success-subtle text-success",
                tone === "warn" && "bg-warning-subtle text-warning",
                tone === "err" && "bg-destructive/10 text-destructive",
                tone === "muted" && "bg-surface-2 text-muted-foreground",
              )}
            >
              {icon}
            </span>
          )}
          <div className="space-y-2">
            <h1 className="text-[28px] font-extrabold tracking-tight">{title}</h1>
            <div className="text-muted-foreground">{body}</div>
          </div>
          {children}
        </section>
      </div>
    </AppShell>
  );
}

function OrderFacts({
  order,
  extra,
}: {
  order: PaymentOrderResponse;
  extra?: [string, ReactNode][];
}) {
  const rows: [string, ReactNode][] = [
    ["Credits", pluralize(order.credits, "credit")],
    ["Amount", <span className="font-mono">{formatMoneyValue(order.amount, "en")}</span>],
    ...(order.provider_reference
      ? ([
          [
            "PayPal order ID",
            <span className="break-all font-mono text-xs">{order.provider_reference}</span>,
          ],
        ] as [string, ReactNode][])
      : []),
    [
      "Started",
      new Date(order.created_at).toLocaleString("en", { dateStyle: "medium", timeStyle: "short" }),
    ],
    ...(extra ?? []),
  ];
  return (
    <dl className="grid w-full grid-cols-[auto_1fr] gap-x-6 gap-y-2.5 rounded-[16px] bg-surface-2 px-5 py-4 text-left text-sm">
      {rows.map(([label, value]) => (
        <Fragment key={label}>
          <dt className="text-muted-foreground">{label}</dt>
          <dd className="min-w-0 text-right">{value}</dd>
        </Fragment>
      ))}
    </dl>
  );
}

export function BillingSuccessPage({ orderId = "" }: { orderId?: string }) {
  const { query, state } = useBillingReturnOrder(orderId);
  const { query: balanceQuery } = useCreditBalanceData();
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, []);

  if (!orderId) {
    return (
      <PaymentResultCard
        tone="muted"
        icon={<CreditCard className="size-8" />}
        title="Payment order missing"
        body="The checkout return URL did not include a payment order. Open Billing to check your recent orders."
      >
        <Button asChild size="lg" className="w-full">
          <Link to="/billing">View billing</Link>
        </Button>
      </PaymentResultCard>
    );
  }

  if (state.kind === "loading") {
    return (
      <PaymentResultCard
        tone="spin"
        icon={null}
        title="Checking payment status…"
        body="We’re confirming your payment with PayPal."
      />
    );
  }

  if (state.kind === "error" || !query.data) {
    return (
      <PaymentResultCard
        tone="err"
        icon={<XCircle className="size-8" />}
        title="Could not confirm payment"
        body="We couldn’t confirm your payment yet. Please try again; if you were charged, your credits will be added once the payment is confirmed."
      >
        <Button size="lg" className="w-full" onClick={() => void query.refetch()}>
          <RotateCcw />
          Try again
        </Button>
      </PaymentResultCard>
    );
  }

  const order = query.data;

  if (isAwaitingPaymentConfirmation(order.status)) {
    const waitedMinutes = (now - new Date(order.created_at).getTime()) / 60_000;
    return (
      <PaymentResultCard
        tone="spin"
        icon={null}
        title="Waiting for PayPal confirmation"
        body={`PayPal is confirming your ${formatMoneyValue(order.amount, "en")} payment. Credits are added automatically as soon as it clears.`}
      >
        <p
          role="status"
          aria-live="polite"
          className="flex items-center gap-2 rounded-[12px] bg-surface-2 px-4 py-2.5 text-sm"
        >
          <RotateCcw className="size-4" />
          Checking again automatically every few seconds
        </p>
        <OrderFacts order={order} />
        {waitedMinutes >= 10 && (
          <p className="w-full rounded-[12px] border px-4 py-3 text-left text-sm">
            Still waiting after 10 minutes?{" "}
            <Link to="/contact" className="font-semibold text-accent-ink hover:underline">
              Contact support
            </Link>{" "}
            with the PayPal order ID above. You won’t be charged twice.
          </p>
        )}
        <div className="flex flex-wrap justify-center gap-2">
          <Button variant="outline" onClick={() => void query.refetch()}>
            <RotateCcw />
            Check now
          </Button>
          <Button asChild variant="ghost">
            <Link to="/billing">Back to Billing — we’ll keep checking</Link>
          </Button>
        </div>
      </PaymentResultCard>
    );
  }

  if (order.status === "paid") {
    return (
      <PaymentResultCard
        tone="ok"
        icon={<Check className="size-9" strokeWidth={2.4} />}
        title="Payment successful"
        body={`${pluralize(order.credits, "credit")} added to your balance. Thanks for your purchase!`}
      >
        <OrderFacts
          order={order}
          extra={
            balanceQuery.data
              ? [
                  [
                    "New balance",
                    <b className="font-mono text-accent-ink">
                      {pluralize(balanceQuery.data.available, "credit")}
                    </b>,
                  ],
                ]
              : []
          }
        />
        <Button asChild size="lg" className="w-full">
          <Link to="/channels">Go to Channels</Link>
        </Button>
        <Link
          to="/billing/$id"
          params={{ id: order.id }}
          className="text-sm font-bold text-accent-ink hover:underline"
        >
          View order
        </Link>
      </PaymentResultCard>
    );
  }

  const refunded = order.status === "partially_refunded" || order.status === "refunded";
  return (
    <PaymentResultCard
      tone={refunded ? "muted" : "err"}
      icon={refunded ? <CreditCard className="size-8" /> : <XCircle className="size-8" />}
      title={refunded ? "Payment has a refund status" : "Payment was not completed"}
      body={
        refunded
          ? `This purchase is ${paymentReturnStatusLabel(order.status)}. Your current balance is shown in Usage.`
          : `This purchase is ${paymentReturnStatusLabel(order.status)}. No credits were added.`
      }
    >
      <OrderFacts order={order} />
      <Button asChild size="lg" className="w-full">
        <Link to="/billing">Back to billing</Link>
      </Button>
    </PaymentResultCard>
  );
}

function paymentReturnStatusLabel(status: string) {
  return status.replaceAll("_", " ");
}

export function BillingCanceledPage({ orderId = "" }: { orderId?: string }) {
  const { query, state } = useBillingReturnOrder(orderId);

  if (!orderId) {
    return (
      <PaymentResultCard
        tone="muted"
        icon={<XCircle className="size-8" />}
        title="Payment cancelled"
        body="You left checkout before completing a purchase. No payment was taken and your balance hasn’t changed."
      >
        <Button asChild size="lg" className="w-full">
          <Link to="/billing">Back to billing</Link>
        </Button>
        <span className="text-xs text-muted-foreground">
          Having trouble paying?{" "}
          <Link to="/contact" className="font-semibold text-accent-ink hover:underline">
            Contact support
          </Link>
        </span>
      </PaymentResultCard>
    );
  }

  if (state.kind === "loading") {
    return (
      <PaymentResultCard
        tone="spin"
        icon={null}
        title="Checking your payment status…"
        body="One moment."
      />
    );
  }

  if (state.kind === "error" || !query.data) {
    return (
      <PaymentResultCard
        tone="err"
        icon={<XCircle className="size-8" />}
        title="Could not check payment order"
        body="Open Billing to review the order again. SaveStream will not infer cancellation or payment from this page alone."
      >
        <Button size="lg" className="w-full" onClick={() => void query.refetch()}>
          <RotateCcw />
          Try again
        </Button>
      </PaymentResultCard>
    );
  }

  const order = query.data;
  const paid = order.status === "paid";
  const awaiting = isAwaitingPaymentConfirmation(order.status);

  return (
    <PaymentResultCard
      tone={paid ? "ok" : awaiting ? "warn" : "muted"}
      icon={paid ? <CheckCircle2 className="size-8" /> : <XCircle className="size-8" />}
      title={
        paid
          ? "Payment was already confirmed"
          : awaiting
            ? "Checkout left before confirmation"
            : "Payment cancelled"
      }
      body={
        paid
          ? "This purchase was paid. The credits are in your balance."
          : awaiting
            ? "This purchase is still pending. If you completed payment, the credits will be added once it is confirmed; check Billing again in a minute."
            : `This purchase is ${paymentReturnStatusLabel(order.status)}. No credits were added and your balance hasn’t changed.`
      }
    >
      <OrderFacts order={order} />
      <div className="flex w-full flex-col gap-2">
        <Button asChild size="lg" className="w-full">
          <Link to="/billing">Back to billing</Link>
        </Button>
        {awaiting && (
          <Button variant="outline" onClick={() => void query.refetch()}>
            <RotateCcw />
            Check status
          </Button>
        )}
      </div>
    </PaymentResultCard>
  );
}

const orderTimelineLabel: Partial<Record<PaymentStatusValue, string>> = {
  paid: "Payment captured and credits added",
  failed: "Payment failed — no credits added",
  cancelled: "Checkout cancelled",
  expired: "Checkout expired",
  refunded: "Refunded",
  partially_refunded: "Partially refunded",
};

export function BillingOrderPage({ orderId }: { orderId: string }) {
  const { query, state } = useBillingReturnOrder(orderId);
  const { user } = useAuth();

  if (state.kind === "loading") {
    return (
      <AppShell>
        <PageHeader title="Order" subtitle="Loading order…" />
        <div className="h-48 animate-pulse rounded-[20px] border bg-surface-2" aria-busy="true" />
      </AppShell>
    );
  }
  if (state.kind === "error" || !query.data) {
    return (
      <AppShell>
        <PageHeader title="Order" />
        <ErrorState
          title="Could not load this order"
          body="It may not exist or belong to another account."
          onRetry={() => void query.refetch()}
        />
      </AppShell>
    );
  }
  const order = query.data;
  const awaiting = isAwaitingPaymentConfirmation(order.status);
  const steps: { title: string; at: string | null; done: boolean }[] = [
    { title: "Order created", at: order.created_at, done: true },
    ...(awaiting
      ? [{ title: "Waiting for PayPal to confirm the payment", at: null, done: false }]
      : [
          {
            title: orderTimelineLabel[order.status] ?? paymentReturnStatusLabel(order.status),
            at: order.updated_at,
            done: true,
          },
        ]),
  ];
  const dateTime = (value: string) =>
    new Date(value).toLocaleString("en", { dateStyle: "medium", timeStyle: "short" });
  return (
    <AppShell>
      <div className="flex flex-col gap-5">
        <nav
          aria-label="Breadcrumb"
          className="flex items-center gap-2 text-sm text-muted-foreground"
        >
          <Link to="/billing" className="font-semibold text-accent-ink hover:underline">
            Billing
          </Link>
          <span aria-hidden="true">/</span>
          <span aria-current="page" className="font-mono text-foreground">
            {order.id.slice(0, 8)}
          </span>
        </nav>
        <PageHeader
          title={`${pluralize(order.credits, "credit")} · ${formatMoneyValue(order.amount, "en")}`}
          subtitle={`Order ${order.id} · ${dateTime(order.created_at)}`}
          action={
            <span
              className={cn(
                "rounded-full px-3 py-1 text-sm font-bold",
                order.status === "paid"
                  ? "bg-success-subtle text-success"
                  : awaiting
                    ? "bg-warning-subtle text-warning-foreground"
                    : "bg-surface-2 text-muted-foreground",
              )}
            >
              {paymentReturnStatusLabel(order.status).replace(/^./, (c) => c.toUpperCase())}
            </span>
          }
        />
        <div className="flex flex-wrap items-start gap-5">
          <section
            aria-labelledby="receipt"
            className="flex min-w-0 flex-[3_1_480px] flex-col gap-4 rounded-[20px] border bg-surface p-6"
          >
            <h2 id="receipt" className="text-[17px] font-bold">
              Receipt
            </h2>
            <dl className="grid grid-cols-[minmax(140px,auto)_1fr] gap-x-6 gap-y-2.5 text-sm">
              <dt className="text-muted-foreground">Credits</dt>
              <dd className="font-mono">{order.credits.toLocaleString("en")}</dd>
              <dt className="text-muted-foreground">Amount</dt>
              <dd className="font-mono">
                {formatMoneyValue(order.amount, "en")} {order.amount.currency}
              </dd>
              <dt className="text-muted-foreground">Paid with</dt>
              <dd>{order.provider === "paypal" ? "PayPal" : (order.provider ?? "—")}</dd>
              {order.provider_reference && (
                <>
                  <dt className="text-muted-foreground">PayPal order ID</dt>
                  <dd className="flex flex-wrap items-center gap-2 font-mono">
                    <span className="break-all">{order.provider_reference}</span>
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => {
                        void navigator.clipboard?.writeText(order.provider_reference ?? "");
                        toast.success("Copied");
                      }}
                    >
                      Copy
                    </Button>
                  </dd>
                </>
              )}
              <dt className="text-muted-foreground">Date</dt>
              <dd>{dateTime(order.created_at)}</dd>
              {user && (
                <>
                  <dt className="text-muted-foreground">Account</dt>
                  <dd>{user.email}</dd>
                </>
              )}
            </dl>
            <p className="text-xs text-muted-foreground">
              Your payment receipt is issued by PayPal. This page is SaveStream’s order record.
            </p>
          </section>
          <section
            aria-labelledby="timeline"
            className="flex flex-[2_1_320px] flex-col gap-4 rounded-[20px] border bg-surface p-6"
          >
            <h2 id="timeline" className="text-[17px] font-bold">
              Status
            </h2>
            <ol className="flex flex-col">
              {steps.map((step, index) => (
                <li key={step.title} className="flex gap-3.5">
                  <div className="flex flex-col items-center">
                    <span
                      className={cn(
                        "grid size-6 shrink-0 place-items-center rounded-full",
                        step.done ? "bg-success text-white" : "border-2 border-primary",
                      )}
                    >
                      {step.done ? (
                        <Check className="size-3.5" />
                      ) : (
                        <span className="size-2 animate-pulse rounded-full bg-primary" />
                      )}
                    </span>
                    {index < steps.length - 1 && (
                      <span className="min-h-5 w-0.5 flex-1 bg-success" />
                    )}
                  </div>
                  <div className="pb-4">
                    <b className="block text-sm">{step.title}</b>
                    {step.at && (
                      <span className="font-mono text-xs text-muted-foreground">
                        {dateTime(step.at)}
                      </span>
                    )}
                  </div>
                </li>
              ))}
            </ol>
          </section>
        </div>
        {order.status === "paid" && (
          <section
            aria-label="Refunds"
            className="flex flex-wrap items-center gap-4 rounded-[20px] border bg-surface p-5"
          >
            <span className="grid size-10 place-items-center rounded-[12px] bg-primary-subtle text-accent-ink">
              <CreditCard className="size-5" />
            </span>
            <div className="min-w-[240px] flex-1">
              <b className="block">Need a refund?</b>
              <span className="text-sm text-muted-foreground">
                Requests are reviewed under our Refund Policy. Credits already used for recordings
                may reduce or rule out a refund.
              </span>
            </div>
            <div className="flex gap-2">
              <Button asChild variant="outline">
                <Link to="/refund">Refund Policy</Link>
              </Button>
              <Button asChild>
                <Link to="/contact">Request a refund</Link>
              </Button>
            </div>
          </section>
        )}
      </div>
    </AppShell>
  );
}

function formatAdminDuration(seconds: number) {
  const total = Math.max(0, Math.round(seconds));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const secs = total % 60;
  if (hours) return `${hours}h ${minutes}m`;
  if (minutes) return `${minutes}m ${secs}s`;
  return `${secs}s`;
}

function formatAdminBytes(bytes: number) {
  if (bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let value = bytes;
  let index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index += 1;
  }
  return `${value >= 10 || index === 0 ? value.toFixed(0) : value.toFixed(1)} ${units[index]}`;
}

function adminSourceLabel(recording: RecordingResponse) {
  return recording.creator?.display_name || recording.creator?.username || recording.source.value;
}

type AdminJobStep = {
  label: string;
  state: "done" | "current" | "failed" | "todo";
  at: string | null;
};

const adminJobStages = ["Queued", "Resolving", "Recording", "Processing", "Uploading"] as const;

/** Timeline of a recording job, from the status and the timestamps the API returns. */
function adminJobTimeline(item: RecordingResponse): AdminJobStep[] {
  const stageOf: Partial<Record<RecordingStatusValue, number>> = {
    queued: 0,
    waiting_for_cloud_slot: 0,
    resolving: 1,
    waiting_live: 1,
    recording: 2,
    stop_requested: 2,
    processing: 3,
    uploading: 4,
  };
  const terminal = ["completed", "failed", "stopped", "missed_no_cloud_slot"].includes(item.status);
  const failed = item.status === "failed" || item.status === "missed_no_cloud_slot";
  // A failed job only shows the stages it really reached.
  const reached = !terminal
    ? (stageOf[item.status] ?? 0)
    : !failed
      ? adminJobStages.length
      : item.duration_seconds > 0
        ? 3
        : item.started_at
          ? 2
          : 1;
  const time = (value: string | null | undefined) =>
    value
      ? new Date(value).toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
        })
      : null;
  const steps: AdminJobStep[] = adminJobStages.map((label, index) => ({
    label,
    state: index < reached ? "done" : index === reached && !terminal ? "current" : "todo",
    at: index === 0 ? time(item.created_at) : index === 2 ? time(item.started_at) : null,
  }));
  const lastLabel =
    item.status === "completed"
      ? "Completed"
      : item.status === "stopped"
        ? "Stopped"
        : item.status === "missed_no_cloud_slot"
          ? "Missed"
          : "Failed";
  steps.push({
    label: terminal ? lastLabel : "Completed",
    state: terminal ? (failed ? "failed" : "done") : "todo",
    at: terminal ? time(item.ended_at ?? item.updated_at) : null,
  });
  return steps;
}

function AdminRecordingStatusPill({ status }: { status: RecordingStatusValue }) {
  const className =
    status === "completed"
      ? "bg-success-subtle text-success"
      : status === "failed"
        ? "bg-recording-subtle text-destructive"
        : status === "recording"
          ? "bg-info-subtle text-info"
          : status === "stopped"
            ? "bg-muted text-muted-foreground"
            : "bg-warning-subtle text-warning-foreground";

  return (
    <span
      className={cn(
        "inline-flex h-6 items-center whitespace-nowrap rounded-full px-[9px] text-xs font-bold",
        className,
      )}
    >
      {status.replaceAll("_", " ")}
    </span>
  );
}

export function AdminWorkersPage() {
  return isDemoMode ? <DemoAdminWorkersPage /> : <ProductionAdminWorkersPage />;
}

function ProductionAdminWorkersPage() {
  const snapshot = useAdminOperationalSnapshotData();

  if (snapshot.isPending) {
    return (
      <AppShell>
        <PageHeader title="Workers & queues" subtitle="Loading operational state…" />
        <div className="h-48 animate-pulse rounded-lg border bg-muted" aria-busy="true" />
      </AppShell>
    );
  }

  if (snapshot.isError || !snapshot.data) {
    return (
      <AppShell>
        <PageHeader title="Workers & queues" />
        <ErrorState
          title="Could not load worker-facing operations"
          body="SaveStream could not load the backend operations snapshot."
          onRetry={() => snapshot.refetch()}
        />
      </AppShell>
    );
  }

  const data = snapshot.data;
  return (
    <AppShell>
      <PageHeader
        title="Workers & queues"
        subtitle="Aggregate backend workload signals. Refreshes every 10 seconds while open."
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
        <StateBanner
          tone="info"
          icon={Server}
          title="Per-worker telemetry is not exposed by the backend"
          body="SaveStream currently exposes operational counters, not worker IDs, CPU, memory, heartbeat, logs, versions, or drain controls. Production intentionally does not simulate those details."
        />
      </div>

      <div className="grid overflow-hidden rounded-[18px] border bg-surface shadow-card sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Active recordings"
          value={String(data.active_recordings)}
          detail="Current recording workload"
          icon={Radio}
        />
        <StatCard
          label="Pending outbox"
          value={String(data.pending_outbox_events)}
          detail="Events waiting to publish"
          icon={Clock3}
        />
        <StatCard
          label={`Recent failures (${failureWindowLabel(data.failed_recordings_window_seconds ?? 900)})`}
          value={String(data.failed_recordings_recent)}
          detail="Live count. Admin Overview shows the last 24h, refreshed hourly"
          icon={AlertTriangle}
        />
        <StatCard
          label="Paused error watches"
          value={String(data.paused_error_watches)}
          detail="Watches paused after errors"
          icon={ShieldCheck}
        />
      </div>

      <section className="mt-8 rounded-[18px] border bg-surface p-5">
        <h2 className="text-[16px] font-bold">Operational boundaries</h2>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">
          Browser admin pages never receive the metrics token and do not call /metrics. Detailed
          worker telemetry requires a future authenticated admin API before this page can safely
          show a worker table or perform worker actions.
        </p>
      </section>
    </AppShell>
  );
}

/* ---------------- Admin: workers ---------------- */
function failureWindowLabel(seconds: number) {
  if (seconds % 3600 === 0) return `last ${seconds / 3600}h`;
  return `last ${Math.max(1, Math.round(seconds / 60))} min`;
}

function WorkerBadge({ status }: { status: WorkerStatus }) {
  if (status === "Recording" || status === "Processing") return <StatusBadge status={status} />;
  const s = {
    Idle: ["border-success/20 bg-success-subtle text-success", "Idle · healthy"],
    Offline: ["border-destructive/20 bg-recording-subtle text-destructive", "Offline"],
    Draining: ["border-warning/30 bg-warning-subtle text-warning-foreground", "Draining"],
  }[status];
  return (
    <span
      className={cn(
        "inline-flex h-6 items-center gap-1.5 rounded-md border px-2 text-xs font-medium",
        s[0],
      )}
    >
      {status === "Offline" ? (
        <AlertTriangle className="size-3" />
      ) : (
        <span className="size-1.5 rounded-full bg-current" />
      )}
      {s[1]}
    </span>
  );
}
function DemoAdminWorkersPage() {
  const { t } = usePreferences();
  const [list, setList] = useState(workerList);
  const [drain, setDrain] = useState<Worker | null>(null);
  const [detail, setDetail] = useState<Worker | null>(null);
  const online = list.filter((w) => w.status !== "Offline").length;
  const actions = (w: Worker) => (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" aria-label={`Actions for ${w.id}`}>
          <MoreHorizontal />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onSelect={() => setDetail(w)}>View details & logs</DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem
          disabled={w.status === "Offline" || w.status === "Draining"}
          onSelect={() => setDrain(w)}
        >
          Drain worker
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
  return (
    <AppShell>
      <PageHeader title="Workers" subtitle="Recorder and processor worker health." />
      <div className="mb-6 grid grid-cols-2 overflow-hidden rounded-lg border lg:grid-cols-4">
        <StatCard
          label="Online"
          value={`${online} / ${list.length}`}
          detail="Heartbeat < 60s"
          icon={Server}
        />
        <StatCard
          label="Recording"
          value={String(list.filter((w) => w.status === "Recording").length)}
          detail="Active streams"
          icon={Radio}
        />
        <StatCard
          label="Processing"
          value={String(list.filter((w) => w.status === "Processing").length)}
          detail="Finalizing jobs"
          icon={FileVideo}
        />
        <StatCard
          label="Idle"
          value={String(list.filter((w) => w.status === "Idle").length)}
          detail="Available capacity"
          icon={Gauge}
        />
      </div>
      {list.some((w) => w.status === "Offline") && (
        <div className="mb-4">
          <StateBanner
            tone="warning"
            title="1 worker is offline"
            body="recorder-04 stopped sending heartbeats 14 minutes ago. Jobs are being assigned to other workers automatically."
          />
        </div>
      )}
      <div className="hidden overflow-hidden rounded-lg border bg-surface md:block">
        <table className="w-full text-sm">
          <thead className="bg-surface-subtle text-left text-[10px] uppercase text-muted-foreground">
            <tr>
              {["Worker", "Status", "Current job", "CPU", "Memory", "Heartbeat", "Version", ""].map(
                (h) => (
                  <th key={h} className="px-4 py-2 font-medium">
                    {h}
                  </th>
                ),
              )}
            </tr>
          </thead>
          <tbody>
            {list.map((w) => (
              <tr key={w.id} className="border-t">
                <td className={cn("px-4 py-3", mono)}>{w.id}</td>
                <td className="px-4 py-3">
                  <WorkerBadge status={w.status} />
                </td>
                <td className={cn("px-4 py-3", mono)}>
                  {w.currentJob ? (
                    <Link
                      to="/admin/jobs/$id"
                      params={{ id: w.currentJob }}
                      className="text-primary hover:underline"
                    >
                      {w.currentJob}
                    </Link>
                  ) : (
                    "—"
                  )}
                </td>
                <td className={cn("px-4 py-3", mono)}>{w.cpu}</td>
                <td className={cn("px-4 py-3", mono)}>{w.memory}</td>
                <td className={cn("px-4 py-3", mono, w.status === "Offline" && "text-destructive")}>
                  {w.heartbeat}
                </td>
                <td className={cn("px-4 py-3", mono)}>{w.version}</td>
                <td className="px-2 py-3 text-right">{actions(w)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="space-y-3 md:hidden">
        {list.map((w) => (
          <div key={w.id} className="rounded-lg border bg-surface p-4">
            <div className="flex items-center justify-between">
              <span className="font-mono text-sm font-medium">{w.id}</span>
              {actions(w)}
            </div>
            <div className="mt-2">
              <WorkerBadge status={w.status} />
            </div>
            <dl className="mt-3 grid grid-cols-3 gap-2 text-xs">
              <div>
                <dt className="text-muted-foreground">CPU</dt>
                <dd className="font-mono">{w.cpu}</dd>
              </div>
              <div>
                <dt className="text-muted-foreground">Memory</dt>
                <dd className="font-mono">{w.memory}</dd>
              </div>
              <div>
                <dt className="text-muted-foreground">Heartbeat</dt>
                <dd className={cn("font-mono", w.status === "Offline" && "text-destructive")}>
                  {w.heartbeat}
                </dd>
              </div>
            </dl>
          </div>
        ))}
      </div>
      <ConfirmDialog
        open={!!drain}
        onOpenChange={(o) => !o && setDrain(null)}
        title={`Drain ${drain?.id}?`}
        body="The worker finishes its current job and stops accepting new jobs. Use this before deploys or maintenance."
        confirmLabel="Drain worker"
        onConfirm={() => {
          const id = drain?.id;
          setList((l) => l.map((w) => (w.id === id ? { ...w, status: "Draining" } : w)));
          setDrain(null);
          toast.success(`${id} is draining`);
        }}
      />
      <Sheet open={!!detail} onOpenChange={(o) => !o && setDetail(null)}>
        <SheetContent className="w-full overflow-y-auto sm:max-w-lg">
          {detail && (
            <>
              <SheetHeader>
                <SheetTitle className="font-mono">{detail.id}</SheetTitle>
                <SheetDescription>
                  {detail.kind} · {detail.region} · {detail.version}
                </SheetDescription>
              </SheetHeader>
              <div className="mt-6 space-y-5">
                <WorkerBadge status={detail.status} />
                <dl className="grid grid-cols-2 gap-4 text-sm">
                  {[
                    ["Current job", detail.currentJob ?? "—"],
                    ["Heartbeat", detail.heartbeat],
                    ["CPU", detail.cpu],
                    ["Memory", detail.memory],
                  ].map(([a, b]) => (
                    <div key={a}>
                      <dt className="text-xs text-muted-foreground">{a}</dt>
                      <dd className="mt-1 font-mono">{b}</dd>
                    </div>
                  ))}
                </dl>
                <div>
                  <p className="mb-2 text-xs font-medium text-muted-foreground">
                    Recent logs (placeholder)
                  </p>
                  <pre className="max-h-72 overflow-auto rounded-md bg-player p-3 font-mono text-[11px] leading-5 text-player-foreground">{`[13:58:02] heartbeat ok cpu=${detail.cpu}\n[13:57:32] heartbeat ok\n[13:22:17] job ${detail.currentJob ?? "—"} recording started\n[13:22:15] assigned job\n[12:00:00] worker boot ${detail.version}`}</pre>
                </div>
              </div>
            </>
          )}
        </SheetContent>
      </Sheet>
    </AppShell>
  );
}

const productionJobStatuses = [
  "queued",
  "resolving",
  "waiting_live",
  "recording",
  "processing",
  "uploading",
  "completed",
  "failed",
  "stop_requested",
  "stopped",
] as const satisfies readonly RecordingStatusValue[];

export function AdminJobsPage() {
  return isDemoMode ? <DemoAdminJobsPage /> : <ProductionAdminJobsPage />;
}

function ProductionAdminJobsPage() {
  const [queryText, setQueryText] = useState("");
  const [status, setStatus] = useState<"all" | RecordingStatusValue>("all");
  const recordings = useAdminRecordingsData(status === "all" ? null : status);
  const retry = useAdminRetryRecordingMutation();

  if (recordings.isPending) {
    return (
      <AppShell>
        <PageHeader title="Recording jobs" subtitle="Loading backend recordings…" />
        <div className="h-64 animate-pulse rounded-lg border bg-muted" aria-busy="true" />
      </AppShell>
    );
  }

  if (recordings.isError || !recordings.data) {
    return (
      <AppShell>
        <PageHeader title="Recording jobs" />
        <ErrorState
          title="Could not load recording jobs"
          body="SaveStream could not load the admin recording list."
          onRetry={() => recordings.refetch()}
        />
      </AppShell>
    );
  }

  const normalizedQuery = queryText.trim().toLowerCase();
  const list = recordings.data.items.filter((recording) => {
    if (!normalizedQuery) return true;
    return [
      recording.id,
      adminSourceLabel(recording),
      recording.source.value,
      recording.error?.code ?? "",
      recording.error?.message ?? "",
    ]
      .join(" ")
      .toLowerCase()
      .includes(normalizedQuery);
  });

  const retryRecording = (recordingId: string) => {
    void retry
      .mutateAsync(recordingId)
      .then((result) =>
        toast.success("Recording retry queued", {
          description: `New recording ${result.recording.id}`,
        }),
      )
      .catch((error) =>
        toast.error("Could not retry recording", {
          description:
            error instanceof Error ? error.message : "The retry request could not be completed.",
        }),
      );
  };

  return (
    <AppShell>
      <PageHeader
        title="Recording jobs"
        subtitle="Admin view of backend recording records. Refreshes every 10 seconds while open."
        action={
          <Button
            variant="outline"
            disabled={recordings.isFetching}
            onClick={() => void recordings.refetch()}
          >
            <RotateCcw />
            {recordings.isFetching ? "Refreshing…" : "Refresh"}
          </Button>
        }
      />

      <FilterBar>
        <div className="flex-1">
          <SearchInput
            value={queryText}
            onChange={setQueryText}
            placeholder="Search recording ID, creator, source, or error"
          />
        </div>
        <Select value={status} onValueChange={(value) => setStatus(value as typeof status)}>
          <SelectTrigger className="w-44" aria-label="Recording status">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All statuses</SelectItem>
            {productionJobStatuses.map((item) => (
              <SelectItem key={item} value={item}>
                {item.replaceAll("_", " ")}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </FilterBar>

      {recordings.data.pagination.has_more && (
        <div className="mb-4">
          <StateBanner
            tone="info"
            title="Showing the first 100 records"
            body="The backend reports more recordings than this page currently loads. Narrow the status filter to reduce the result set."
          />
        </div>
      )}

      {list.length === 0 ? (
        <EmptyState
          icon={Search}
          title="No recording jobs match"
          body="Try another status or search term."
        />
      ) : (
        <>
          <div className="hidden overflow-x-auto rounded-lg border bg-surface lg:block">
            <table className="w-full min-w-[1050px] text-xs">
              <thead className="bg-surface-subtle text-left text-[10px] uppercase text-muted-foreground">
                <tr>
                  {[
                    "Recording ID",
                    "Creator / source",
                    "Status",
                    "Started",
                    "Duration",
                    "Output",
                    "Cost",
                    "Error",
                    "",
                  ].map((heading) => (
                    <th key={heading} className="px-4 py-3 font-bold">
                      {heading}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {list.map((recording) => (
                  <tr key={recording.id} className="border-t">
                    <td className="px-4 py-3">
                      <Link
                        to="/admin/jobs/$id"
                        params={{ id: recording.id }}
                        className="font-mono font-medium text-primary hover:underline"
                      >
                        {recording.id}
                      </Link>
                    </td>
                    <td className="px-4 py-3">
                      <p className="font-medium">{adminSourceLabel(recording)}</p>
                      <p className="mt-1 font-mono text-[10px] text-muted-foreground">
                        {recording.source.type}: {recording.source.value}
                      </p>
                    </td>
                    <td className="px-4 py-3">
                      <AdminRecordingStatusPill status={recording.status} />
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 font-mono">
                      {recording.started_at ? new Date(recording.started_at).toLocaleString() : "—"}
                    </td>
                    <td className="px-4 py-3 font-mono">
                      {formatAdminDuration(recording.duration_seconds)}
                    </td>
                    <td className="px-4 py-3 font-mono">
                      {formatAdminBytes(recording.bytes_recorded)}
                    </td>
                    <td className="px-4 py-3 font-mono">
                      {recording.actual_cost === null ? "—" : `${recording.actual_cost} credits`}
                    </td>
                    <td
                      className="max-w-56 truncate px-4 py-3 text-muted-foreground"
                      title={recording.error?.message ?? ""}
                    >
                      {recording.error?.code ?? "—"}
                    </td>
                    <td className="px-4 py-3 text-right">
                      {recording.actions.can_retry && (
                        <Button
                          size="sm"
                          variant="outline"
                          disabled={retry.isPending}
                          onClick={() => retryRecording(recording.id)}
                        >
                          <RotateCcw />
                          Retry
                        </Button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="space-y-3 lg:hidden">
            {list.map((recording) => (
              <div key={recording.id} className="rounded-lg border bg-surface p-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <Link
                      to="/admin/jobs/$id"
                      params={{ id: recording.id }}
                      className="truncate font-mono text-sm font-medium text-primary hover:underline"
                    >
                      {recording.id}
                    </Link>
                    <p className="mt-1 truncate text-xs text-muted-foreground">
                      {adminSourceLabel(recording)}
                    </p>
                  </div>
                  <AdminRecordingStatusPill status={recording.status} />
                </div>
                <dl className="mt-4 grid grid-cols-3 gap-3 text-xs">
                  <div>
                    <dt className="text-muted-foreground">Duration</dt>
                    <dd className="mt-1 font-mono">
                      {formatAdminDuration(recording.duration_seconds)}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-muted-foreground">Output</dt>
                    <dd className="mt-1 font-mono">{formatAdminBytes(recording.bytes_recorded)}</dd>
                  </div>
                  <div>
                    <dt className="text-muted-foreground">Cost</dt>
                    <dd className="mt-1 font-mono">
                      {recording.actual_cost === null ? "—" : recording.actual_cost}
                    </dd>
                  </div>
                </dl>
              </div>
            ))}
          </div>
        </>
      )}
    </AppShell>
  );
}

/* ---------------- Admin: jobs ---------------- */
const jobFilters = ["All", "Recording", "Processing", "Error", "Stuck", "Ready"] as const;
function JobStatusCell({ job }: { job: RecordingJob }) {
  return (
    <div className="flex flex-wrap items-center gap-1.5">
      <StatusBadge status={job.status} />
      {job.stuck && (
        <span className="inline-flex h-6 items-center gap-1 rounded-md border border-warning/30 bg-warning-subtle px-2 text-xs font-medium text-warning-foreground">
          <AlertTriangle className="size-3" />
          Stuck
        </span>
      )}
    </div>
  );
}
function DemoAdminJobsPage() {
  const { t } = usePreferences();
  const [q, setQ] = useState("");
  const [f, setF] = useState<(typeof jobFilters)[number]>("All");
  const list = jobList.filter(
    (j) =>
      (f === "All" || (f === "Stuck" ? j.stuck : j.status === f)) &&
      `${j.id} ${j.user} ${j.channel}`.toLowerCase().includes(q.toLowerCase()),
  );
  return (
    <AppShell>
      <PageHeader
        title="Recording jobs"
        subtitle="Inspect active, completed, and failed recording jobs."
      />
      {jobList.some((j) => j.stuck) && (
        <div className="mb-4">
          <StateBanner
            tone="warning"
            title="1 job has a stale heartbeat"
            body="job_5MN04R hasn’t reported for 4 minutes. It will be reassigned automatically after 5 minutes."
            action={
              <Button size="sm" variant="outline" asChild>
                <Link to="/admin/jobs/$id" params={{ id: "job_5MN04R" }}>
                  {t("Inspect")}
                </Link>
              </Button>
            }
          />
        </div>
      )}
      <FilterBar>
        <div className="flex-1">
          <SearchInput value={q} onChange={setQ} placeholder="Search job ID, user, or channel" />
        </div>
        <div className="flex gap-1 overflow-x-auto">
          {jobFilters.map((x) => (
            <Button
              key={x}
              size="sm"
              variant={f === x ? "secondary" : "ghost"}
              onClick={() => setF(x)}
            >
              {x === "Error" ? "Failed" : x}
            </Button>
          ))}
        </div>
      </FilterBar>
      {list.length === 0 ? (
        <EmptyState
          icon={f === "Error" ? CheckCircle2 : Search}
          title={f === "Error" ? "No failed jobs" : "No jobs match"}
          body={
            f === "Error" ? "Nothing has failed in this period." : "Try another search or filter."
          }
        />
      ) : (
        <>
          <div className="hidden overflow-x-auto rounded-lg border bg-surface lg:block">
            <table className="w-full min-w-[1000px] text-xs">
              <thead className="bg-surface-subtle text-left text-[10px] uppercase text-muted-foreground">
                <tr>
                  {[
                    "Job ID",
                    "User",
                    "Channel",
                    "Worker",
                    "Status",
                    "Started",
                    "Duration",
                    "Retries",
                    "Heartbeat",
                    "Error",
                  ].map((h) => (
                    <th key={h} className="px-4 py-2 font-medium">
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {list.map((j) => (
                  <tr key={j.id} className={cn("border-t", j.stuck && "bg-warning-subtle/40")}>
                    <td className="px-4 py-3">
                      <Link
                        to="/admin/jobs/$id"
                        params={{ id: j.id }}
                        className="font-mono font-medium text-primary hover:underline"
                      >
                        {j.id}
                      </Link>
                    </td>
                    <td className="px-4 py-3">{j.user}</td>
                    <td className="px-4 py-3">{j.channel}</td>
                    <td className={cn("px-4 py-3", mono)}>{j.worker}</td>
                    <td className="px-4 py-3">
                      <JobStatusCell job={j} />
                    </td>
                    <td className={cn("px-4 py-3", mono)}>{j.started}</td>
                    <td className={cn("px-4 py-3", mono)}>{j.duration}</td>
                    <td className={cn("px-4 py-3", mono)}>{j.retries}</td>
                    <td
                      className={cn(
                        "px-4 py-3",
                        mono,
                        j.stuck && "font-semibold text-warning-foreground",
                      )}
                    >
                      {j.heartbeat}
                    </td>
                    <td
                      className="max-w-48 truncate px-4 py-3 text-muted-foreground"
                      title={j.error ?? ""}
                    >
                      {j.error?.split(" · ")[0] ?? "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="space-y-3 lg:hidden">
            {list.map((j) => (
              <Link
                key={j.id}
                to="/admin/jobs/$id"
                params={{ id: j.id }}
                className="block rounded-lg border bg-surface p-4"
              >
                <div className="flex items-center justify-between">
                  <span className="font-mono text-sm font-medium">{j.id}</span>
                  <ChevronRight className="size-4 text-muted-foreground" />
                </div>
                <div className="mt-2">
                  <JobStatusCell job={j} />
                </div>
                <p className="mt-3 text-xs text-muted-foreground">
                  {j.user} · {j.channel} · <span className="font-mono">{j.worker}</span>
                </p>
                <p className="mt-1 font-mono text-xs">
                  {j.duration} · heartbeat {j.heartbeat}
                </p>
              </Link>
            ))}
          </div>
        </>
      )}
    </AppShell>
  );
}
export function JobEventTimeline({ events }: { events: JobEvent[] }) {
  return (
    <ol>
      {events.map((e) => (
        <li
          key={e.label}
          className="relative flex gap-3 pb-4 text-sm before:absolute before:left-[7px] before:top-4 before:h-full before:w-px before:bg-border last:before:hidden"
        >
          {e.state === "done" ? (
            <CheckCircle2 className="relative z-10 mt-0.5 size-4 shrink-0 bg-surface text-success" />
          ) : e.state === "failed" ? (
            <XCircle className="relative z-10 mt-0.5 size-4 shrink-0 bg-surface text-destructive" />
          ) : e.state === "active" ? (
            <span className="relative z-10 mt-0.5 grid size-4 shrink-0 place-items-center rounded-full border-2 border-info bg-surface">
              <span className="size-1.5 animate-pulse rounded-full bg-info" />
            </span>
          ) : (
            <span className="relative z-10 mt-0.5 size-4 shrink-0 rounded-full border-2 bg-surface" />
          )}
          <span
            className={cn(
              "w-16 font-mono text-xs",
              e.state === "pending" && "text-muted-foreground",
            )}
          >
            {e.time}
          </span>
          <span
            className={cn(
              "text-sm",
              e.state === "pending" && "text-muted-foreground",
              e.state === "failed" && "font-medium text-destructive",
            )}
          >
            {e.label}
            {e.state === "active" && <span className="ml-2 text-xs text-info">in progress</span>}
            {e.state === "failed" && <span className="ml-2 text-xs">failed</span>}
          </span>
        </li>
      ))}
    </ol>
  );
}
export function AdminJobDetailPage() {
  return isDemoMode ? <DemoAdminJobDetailPage /> : <ProductionAdminJobDetailPage />;
}

function ProductionAdminJobDetailPage() {
  const { id } = useParams({ strict: false }) as { id?: string };
  const recording = useAdminRecordingData(id);
  const retry = useAdminRetryRecordingMutation();
  const [confirmRetry, setConfirmRetry] = useState(false);

  if (recording.isPending) {
    return (
      <AppShell>
        <PageHeader title="Recording job" subtitle="Loading backend recording…" />
        <div className="h-64 animate-pulse rounded-lg border bg-muted" aria-busy="true" />
      </AppShell>
    );
  }

  if (recording.isError || !recording.data) {
    return (
      <AppShell>
        <PageHeader title="Recording job unavailable" />
        <ErrorState
          title="Could not load recording job"
          body="The recording may not exist or the admin API could not load it."
          onRetry={() => recording.refetch()}
        />
      </AppShell>
    );
  }

  const item = recording.data;
  const fields: [string, ReactNode][] = [
    ["Recording ID", item.id],
    ["Creator / source", adminSourceLabel(item)],
    ["Source type", item.source.type],
    ["Source value", item.source.value],
    ["Started", item.started_at ? new Date(item.started_at).toLocaleString() : "—"],
    ["Ended", item.ended_at ? new Date(item.ended_at).toLocaleString() : "—"],
    ["Duration", formatAdminDuration(item.duration_seconds)],
    ["Output", formatAdminBytes(item.bytes_recorded)],
    ["Estimated max cost", `${item.estimated_max_cost} credits`],
    ["Actual cost", item.actual_cost === null ? "—" : `${item.actual_cost} credits`],
    ["Credit reservation", item.credit_reservation_id ?? "—"],
    ["Updated", new Date(item.updated_at).toLocaleString()],
  ];

  const retryRecording = () => {
    void retry
      .mutateAsync(item.id)
      .then((result) => {
        setConfirmRetry(false);
        toast.success("Recording retry queued", {
          description: `New recording ${result.recording.id}`,
        });
      })
      .catch((error) =>
        toast.error("Could not retry recording", {
          description:
            error instanceof Error ? error.message : "The retry request could not be completed.",
        }),
      );
  };

  const steps = adminJobTimeline(item);

  return (
    <AppShell>
      <nav
        className="mb-4 flex items-center gap-2 text-sm text-muted-foreground"
        aria-label="Breadcrumb"
      >
        <Link to="/admin/jobs" className="hover:text-foreground">
          Jobs &amp; LIVE
        </Link>
        <span aria-hidden="true">/</span>
        <span className="truncate font-mono text-foreground" aria-current="page">
          {item.id}
        </span>
      </nav>

      <header className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2.5">
            <h1 className="break-all font-mono text-[22px] font-bold tracking-[-.02em]">
              {item.id}
            </h1>
            <AdminRecordingStatusPill status={item.status} />
          </div>
          <p className="mt-1 text-sm text-muted-foreground">
            {adminSourceLabel(item)} · {item.source.type}{" "}
            <span className="font-mono">{item.source.value}</span>
            {item.started_at ? ` · started ${new Date(item.started_at).toLocaleString()}` : ""}
          </p>
          <p className="mt-1 text-xs text-muted-foreground">
            Active records refresh every 5 seconds.
          </p>
        </div>
        <div className="flex flex-none gap-2">
          <Button
            variant="outline"
            disabled={recording.isFetching}
            onClick={() => void recording.refetch()}
          >
            <RotateCcw />
            Refresh
          </Button>
          {item.actions.can_retry && (
            <Button disabled={retry.isPending} onClick={() => setConfirmRetry(true)}>
              <RotateCcw />
              Retry recording
            </Button>
          )}
        </div>
      </header>

      <section className="mb-6 rounded-[18px] border bg-surface p-6" aria-labelledby="job-timeline">
        <h2 id="job-timeline" className="text-[17px] font-bold tracking-[-.01em]">
          Timeline
        </h2>
        <ol className="mt-5 grid gap-5 sm:grid-cols-3 lg:grid-cols-6 lg:gap-0">
          {steps.map((step, index) => (
            <li key={step.label} className="flex flex-col gap-2">
              <div className="flex items-center">
                <span
                  className={cn(
                    "grid size-7 flex-none place-items-center rounded-full font-mono text-xs font-bold shadow-[0_0_0_4px_var(--surface)]",
                    step.state === "done" && "bg-success text-white",
                    step.state === "failed" && "bg-destructive text-white",
                    step.state === "current" && "bg-primary text-primary-foreground",
                    step.state === "todo" && "bg-surface-2 text-muted-foreground",
                  )}
                >
                  {step.state === "done" ? "✓" : step.state === "failed" ? "!" : index + 1}
                </span>
                {index < steps.length - 1 && (
                  <span
                    className={cn(
                      "mx-1.5 hidden h-[3px] flex-1 rounded-full lg:block",
                      step.state === "done" ? "bg-success" : "bg-surface-2",
                    )}
                  />
                )}
              </div>
              <b className="text-sm">{step.label}</b>
              <span className="font-mono text-xs text-muted-foreground">{step.at ?? "—"}</span>
            </li>
          ))}
        </ol>
      </section>

      {item.error && (
        <div className="mb-6 rounded-[16px] border border-destructive/30 bg-recording-subtle p-4">
          <p className="font-mono text-sm font-bold text-destructive">{item.error.code}</p>
          <p className="mt-2 text-sm">{item.error.message}</p>
          <p className="mt-2 text-xs text-muted-foreground">
            Retryable: {item.error.retryable ? "yes" : "no"}
          </p>
        </div>
      )}

      <div className="grid items-start gap-5 xl:grid-cols-[1.4fr_1fr]">
        <section className="rounded-[18px] border bg-surface p-5">
          <h2 className="text-[17px] font-bold tracking-[-.01em]">Backend recording state</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Only fields returned by the admin recording API are shown.
          </p>
          <dl className="mt-5 grid grid-cols-[170px_1fr] gap-x-4 gap-y-2.5 text-sm">
            {fields.map(([label, value]) => (
              <Fragment key={label}>
                <dt className="text-muted-foreground">{label}</dt>
                <dd className="min-w-0 break-words font-mono text-xs leading-5">{value}</dd>
              </Fragment>
            ))}
          </dl>
        </section>

        <section className="rounded-[18px] border bg-surface p-5">
          <h2 className="text-[17px] font-bold tracking-[-.01em]">Actions exposed by backend</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Retry is available only when the recording response says can_retry. The admin API does
            not expose a browser action to mark a job failed, kill a worker, or edit hidden job
            state.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            Stop, retention, playback and delete are on the{" "}
            <Link to="/admin/jobs" className="font-bold text-accent-ink hover:underline">
              Jobs &amp; LIVE
            </Link>{" "}
            list, each with a reason stored in the audit log.
          </p>
        </section>
      </div>

      <ConfirmDialog
        open={confirmRetry}
        onOpenChange={setConfirmRetry}
        title="Retry this recording?"
        body="SaveStream will create a new recording attempt through the admin retry endpoint. The original recording remains unchanged."
        confirmLabel={retry.isPending ? "Retrying…" : "Retry recording"}
        confirmDisabled={retry.isPending}
        onConfirm={retryRecording}
      />
    </AppShell>
  );
}

function DemoAdminJobDetailPage() {
  const { t } = usePreferences();
  const { id } = useParams({ strict: false }) as { id?: string };
  const job = jobList.find((j) => j.id === id);
  const [confirm, setConfirm] = useState<null | "retry" | "fail">(null);
  if (!job)
    return (
      <AppShell>
        <PageHeader title="Job not found" />
        <EmptyState
          icon={Search}
          title={`No job with ID ${id}`}
          body="It may have been archived."
          action={
            <Button asChild variant="outline">
              <Link to="/admin/jobs">Back to jobs</Link>
            </Button>
          }
        />
      </AppShell>
    );
  const fields: [string, ReactNode][] = [
    ["User", job.user],
    ["Channel", job.channel],
    ["Worker", job.worker],
    ["Room ID", job.roomId],
    ["Source ref", job.sourceRef],
    ["Started", `Sep 27 · ${job.started}`],
    ["Ended", job.ended ? `Sep 27 · ${job.ended}` : "—"],
    ["Duration", job.duration],
    ["Retry count", String(job.retries)],
    ["Last heartbeat", job.heartbeat],
    ["Output", job.bytes],
    [
      "Recording",
      job.recordingId ? (
        <Link
          to="/recordings/$id"
          params={{ id: job.recordingId }}
          className="text-primary hover:underline"
        >
          {job.recordingId}
        </Link>
      ) : (
        "—"
      ),
    ],
  ];
  return (
    <AppShell>
      <Link
        to="/admin/jobs"
        className="mb-4 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="size-4" />
        Jobs
      </Link>
      <PageHeader
        title={job.id}
        subtitle={`${job.channel} · ${job.user}`}
        action={
          <div className="flex gap-2">
            {job.status === "Error" && (
              <Button variant="outline" onClick={() => setConfirm("retry")}>
                <RotateCcw />
                {t("Retry job")}
              </Button>
            )}
            {job.stuck && (
              <Button variant="destructive" onClick={() => setConfirm("fail")}>
                {t("Mark as failed")}
              </Button>
            )}
          </div>
        }
      />
      <div className="mb-6 flex flex-wrap items-center gap-2">
        <JobStatusCell job={job} />
        <span className="text-xs text-muted-foreground">Heartbeat {job.heartbeat}</span>
      </div>
      {job.stuck && (
        <div className="mb-4">
          <StateBanner
            tone="warning"
            title="Heartbeat is stale"
            body="The worker hasn’t reported for 4 minutes. Automatic reassignment happens at 5 minutes."
          />
        </div>
      )}
      {job.error && (
        <div className="mb-6 rounded-lg border border-destructive/30 bg-recording-subtle p-4">
          <p className="text-sm font-medium text-destructive">Error details</p>
          <pre className="mt-2 whitespace-pre-wrap font-mono text-xs leading-5">
            {job.error}
            {"\n"}exit_code=1 attempts={job.retries + 1} partial_output={job.bytes}
          </pre>
        </div>
      )}
      <div className="grid gap-6 lg:grid-cols-[1.2fr_.8fr]">
        <section className="rounded-lg border bg-surface p-5">
          <h2 className="text-sm font-medium">{t("Job context")}</h2>
          <dl className="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-3">
            {fields.map(([a, b]) => (
              <div key={a} className="min-w-0">
                <dt className="text-xs text-muted-foreground">{a}</dt>
                <dd className="mt-1 truncate font-mono text-xs">{b}</dd>
              </div>
            ))}
          </dl>
        </section>
        <section className="rounded-lg border bg-surface p-5">
          <h2 className="mb-4 text-sm font-medium">{t("Timeline")}</h2>
          <JobEventTimeline events={job.timeline} />
        </section>
      </div>
      <ConfirmDialog
        open={confirm === "retry"}
        onOpenChange={(o) => !o && setConfirm(null)}
        title="Retry this job?"
        body="A new processing attempt is queued using the saved partial output. The user is notified when it completes."
        confirmLabel="Retry job"
        onConfirm={() => {
          setConfirm(null);
          toast.success("Retry queued");
        }}
      />
      <ConfirmDialog
        destructive
        open={confirm === "fail"}
        onOpenChange={(o) => !o && setConfirm(null)}
        title="Mark job as failed?"
        body="The worker process is stopped and any partial output is kept. The user will see this recording as failed."
        confirmLabel="Mark as failed"
        onConfirm={() => {
          setConfirm(null);
          toast.success("Job marked as failed");
        }}
      />
    </AppShell>
  );
}

function adminAuditResource(entry: AuditLogResponse) {
  if (!entry.resource_type && !entry.resource_id) return "—";
  return [entry.resource_type, entry.resource_id].filter(Boolean).join(": ");
}

export function AdminErrorsPage() {
  return isDemoMode ? <DemoAdminErrorsPage /> : <ProductionAdminErrorsPage />;
}

function ProductionAdminErrorsPage() {
  const audit = useAdminAuditData();
  const snapshot = useAdminOperationalSnapshotData();
  const [queryText, setQueryText] = useState("");
  const [resourceType, setResourceType] = useState("all");
  const [open, setOpen] = useState<string | null>(null);

  if (audit.isPending) {
    return (
      <AppShell>
        <PageHeader title="Audit & operations" subtitle="Loading backend audit activity…" />
        <div className="h-64 animate-pulse rounded-lg border bg-muted" aria-busy="true" />
      </AppShell>
    );
  }

  if (audit.isError || !audit.data) {
    return (
      <AppShell>
        <PageHeader title="Audit & operations" />
        <ErrorState
          title="Could not load admin audit log"
          body="SaveStream could not load backend audit activity."
          onRetry={() => audit.refetch()}
        />
      </AppShell>
    );
  }

  const normalizedQuery = queryText.trim().toLowerCase();
  const resourceTypes = Array.from(
    new Set(
      audit.data.items
        .map((entry) => entry.resource_type)
        .filter((value): value is string => Boolean(value)),
    ),
  ).sort();

  const list = audit.data.items.filter((entry) => {
    if (resourceType !== "all" && entry.resource_type !== resourceType) return false;
    if (!normalizedQuery) return true;
    return [
      entry.action,
      entry.resource_type ?? "",
      entry.resource_id ?? "",
      entry.actor_user_id ?? "",
      entry.request_id ?? "",
    ]
      .join(" ")
      .toLowerCase()
      .includes(normalizedQuery);
  });

  const selected = audit.data.items.find((entry) => entry.id === open) ?? null;

  const refresh = () => {
    void Promise.all([audit.refetch(), snapshot.refetch()]);
  };

  return (
    <AppShell>
      <PageHeader
        title="Audit & operations"
        subtitle="Real admin audit activity plus backend operational counters."
        action={
          <Button
            variant="outline"
            disabled={audit.isFetching || snapshot.isFetching}
            onClick={refresh}
          >
            <RotateCcw />
            {audit.isFetching || snapshot.isFetching ? "Refreshing…" : "Refresh"}
          </Button>
        }
      />

      <div className="mb-6">
        <StateBanner
          tone="info"
          icon={ShieldCheck}
          title="Audit log is not a raw service-error stream"
          body="The backend exposes administrative audit records and aggregate operational counters. Production does not fabricate worker stack traces, severity, or retry state that the API does not provide."
        />
      </div>

      {snapshot.data && (
        <div className="mb-6 grid overflow-hidden rounded-[18px] border bg-surface shadow-card sm:grid-cols-2 xl:grid-cols-4">
          <StatCard
            label="Recent recording failures"
            value={String(snapshot.data.failed_recordings_recent)}
            detail="Backend failure window"
            icon={AlertTriangle}
          />
          <StatCard
            label="Pending outbox"
            value={String(snapshot.data.pending_outbox_events)}
            detail="Events waiting to publish"
            icon={Clock3}
          />
          <StatCard
            label="Unprocessed payment events"
            value={String(snapshot.data.unprocessed_payment_events)}
            detail="Provider events awaiting processing"
            icon={CreditCard}
          />
          <StatCard
            label="Paused error watches"
            value={String(snapshot.data.paused_error_watches)}
            detail="Watches paused after repeated errors"
            icon={Radio}
          />
        </div>
      )}

      {snapshot.isError && (
        <div className="mb-6">
          <StateBanner
            tone="warning"
            title="Operational counters unavailable"
            body="The audit log is available, but the operations snapshot could not be refreshed."
            action={
              <Button size="sm" variant="outline" onClick={() => void snapshot.refetch()}>
                Retry snapshot
              </Button>
            }
          />
        </div>
      )}

      <FilterBar>
        <div className="flex-1">
          <SearchInput
            value={queryText}
            onChange={setQueryText}
            placeholder="Search action, resource, actor, or request ID"
          />
        </div>
        <Select value={resourceType} onValueChange={setResourceType}>
          <SelectTrigger className="w-44" aria-label="Resource type">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All resources</SelectItem>
            {resourceTypes.map((type) => (
              <SelectItem key={type} value={type}>
                {type}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </FilterBar>

      {audit.data.pagination.has_more && (
        <div className="mb-4">
          <StateBanner
            tone="info"
            title="Showing the first 100 audit entries"
            body="The backend reports additional audit records beyond this page."
          />
        </div>
      )}

      {list.length === 0 ? (
        <EmptyState
          icon={CheckCircle2}
          title="No audit entries match"
          body="Try another search term or resource filter."
        />
      ) : (
        <>
          <div className="relative hidden overflow-x-auto rounded-[16px] border bg-surface md:block">
            <table className="w-full min-w-[900px] text-sm">
              <thead className="bg-surface-2 text-left text-[11px] uppercase tracking-[.06em] text-muted-foreground">
                <tr>
                  {["Time", "Action", "Resource", "Actor", "Request ID"].map((heading) => (
                    <th key={heading} className="px-4 py-3 font-bold">
                      {heading}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {list.map((entry) => (
                  <tr
                    key={entry.id}
                    tabIndex={0}
                    onClick={() => setOpen(entry.id)}
                    onKeyDown={(event) => {
                      if (event.key === "Enter") setOpen(entry.id);
                    }}
                    className="cursor-pointer border-t transition-colors hover:bg-surface-2/60 focus-visible:bg-surface-2 focus-visible:outline-none"
                  >
                    <td className="whitespace-nowrap px-4 py-3 font-mono text-xs text-muted-foreground">
                      {new Date(entry.created_at).toLocaleString()}
                    </td>
                    <td className="px-4 py-3">
                      <span className="inline-flex h-6 items-center rounded-full bg-primary-subtle px-[9px] font-mono text-[11px] font-bold text-accent-ink">
                        {entry.action}
                      </span>
                    </td>
                    <td className="px-4 py-3 font-mono text-xs">{adminAuditResource(entry)}</td>
                    <td className="max-w-44 truncate px-4 py-3 font-mono text-xs">
                      {entry.actor_user_id ?? "system"}
                    </td>
                    <td className="max-w-44 truncate px-4 py-3 font-mono text-xs text-muted-foreground">
                      {entry.request_id ?? "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="space-y-3 md:hidden">
            {list.map((entry) => (
              <button
                key={entry.id}
                type="button"
                onClick={() => setOpen(entry.id)}
                className="block w-full rounded-[16px] border bg-surface p-4 text-left"
              >
                <p className="font-mono text-xs font-medium">{entry.action}</p>
                <p className="mt-2 text-xs text-muted-foreground">{adminAuditResource(entry)}</p>
                <p className="mt-2 font-mono text-[11px] text-muted-foreground">
                  {new Date(entry.created_at).toLocaleString()}
                </p>
              </button>
            ))}
          </div>
        </>
      )}

      <Sheet open={Boolean(selected)} onOpenChange={(next) => !next && setOpen(null)}>
        <SheetContent className="w-full overflow-y-auto sm:max-w-lg">
          {selected && (
            <>
              <SheetHeader>
                <SheetTitle>
                  <span className="inline-flex h-7 items-center rounded-full bg-primary-subtle px-3 font-mono text-sm font-bold text-accent-ink">
                    {selected.action}
                  </span>
                </SheetTitle>
                <SheetDescription>
                  {new Date(selected.created_at).toLocaleString()}
                </SheetDescription>
              </SheetHeader>
              <div className="mt-6 space-y-5">
                <dl className="grid grid-cols-2 gap-4 text-sm">
                  {[
                    ["Audit ID", selected.id],
                    ["Actor", selected.actor_user_id ?? "system"],
                    ["Resource", adminAuditResource(selected)],
                    ["Request ID", selected.request_id ?? "—"],
                    ["IP hint", selected.ip_address ?? "—"],
                    ["User agent", selected.user_agent ?? "—"],
                  ].map(([label, value]) => (
                    <div key={label} className="min-w-0">
                      <dt className="text-xs text-muted-foreground">{label}</dt>
                      <dd className="mt-1 break-words font-mono text-xs">{value}</dd>
                    </div>
                  ))}
                </dl>
                <div>
                  <p className="mb-2 text-xs font-medium text-muted-foreground">Details</p>
                  <pre className="max-h-80 overflow-auto rounded-[12px] bg-[#15122B] p-3.5 font-mono text-xs leading-[1.65] text-[#D9D4F2]">
                    {JSON.stringify(selected.details, null, 2)}
                  </pre>
                </div>
              </div>
            </>
          )}
        </SheetContent>
      </Sheet>
    </AppShell>
  );
}

/* ---------------- Admin: errors ---------------- */
const sevStyle: Record<EventSeverity, string> = {
  Critical: "bg-destructive text-destructive-foreground",
  Error: "bg-recording-subtle text-destructive",
  Warning: "bg-warning-subtle text-warning-foreground",
  Info: "bg-info-subtle text-info",
};
function Severity({ s }: { s: EventSeverity }) {
  return (
    <span
      className={cn(
        "inline-flex h-5 items-center rounded px-1.5 text-[10px] font-semibold uppercase",
        sevStyle[s],
      )}
    >
      {s}
    </span>
  );
}
function EventState({ s }: { s: "Retrying" | "Resolved" | "Open" }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 text-xs",
        s === "Resolved"
          ? "text-success"
          : s === "Retrying"
            ? "text-info"
            : "text-warning-foreground",
      )}
    >
      {s === "Resolved" ? (
        <CheckCircle2 className="size-3" />
      ) : s === "Retrying" ? (
        <RotateCcw className="size-3" />
      ) : (
        <AlertTriangle className="size-3" />
      )}
      {s}
    </span>
  );
}
function DemoAdminErrorsPage() {
  const { t } = usePreferences();
  const [q, setQ] = useState("");
  const [sev, setSev] = useState("all");
  const [st, setSt] = useState("all");
  const [open, setOpen] = useState<string | null>(null);
  const list = systemEvents.filter(
    (e) =>
      (sev === "all" || e.severity === sev) &&
      (st === "all" || e.state === st) &&
      `${e.code} ${e.message} ${e.service} ${e.target}`.toLowerCase().includes(q.toLowerCase()),
  );
  const ev = systemEvents.find((e) => e.id === open);
  return (
    <AppShell>
      <PageHeader
        title="Errors & events"
        subtitle="System events across monitoring, workers, processing, and storage."
      />
      <FilterBar>
        <div className="flex-1">
          <SearchInput
            value={q}
            onChange={setQ}
            placeholder="Search code, message, worker, or job"
          />
        </div>
        <div className="grid grid-cols-2 gap-2 sm:flex">
          <Select value={sev} onValueChange={setSev}>
            <SelectTrigger className="sm:w-36" aria-label="Severity">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All severities</SelectItem>
              {["Critical", "Error", "Warning", "Info"].map((s) => (
                <SelectItem key={s} value={s}>
                  {s}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Select value={st} onValueChange={setSt}>
            <SelectTrigger className="sm:w-32" aria-label="State">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All states</SelectItem>
              {["Open", "Retrying", "Resolved"].map((s) => (
                <SelectItem key={s} value={s}>
                  {s}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </FilterBar>
      {list.length === 0 ? (
        <EmptyState
          icon={CheckCircle2}
          title="No events match"
          body="No errors or events for these filters."
        />
      ) : (
        <>
          <div className="hidden overflow-hidden rounded-lg border bg-surface md:block">
            <table className="w-full text-xs">
              <thead className="bg-surface-subtle text-left text-[10px] uppercase text-muted-foreground">
                <tr>
                  {["Time", "Severity", "Service", "Channel / job", "Code", "Message", "State"].map(
                    (h) => (
                      <th key={h} className="px-4 py-2 font-medium">
                        {h}
                      </th>
                    ),
                  )}
                </tr>
              </thead>
              <tbody>
                {list.map((e) => (
                  <tr
                    key={e.id}
                    tabIndex={0}
                    onClick={() => setOpen(e.id)}
                    onKeyDown={(k) => k.key === "Enter" && setOpen(e.id)}
                    className="cursor-pointer border-t hover:bg-accent focus-visible:bg-accent focus-visible:outline-none"
                  >
                    <td className={cn("whitespace-nowrap px-4 py-3", mono)}>{e.timestamp}</td>
                    <td className="px-4 py-3">
                      <Severity s={e.severity} />
                    </td>
                    <td className={cn("px-4 py-3", mono)}>{e.service}</td>
                    <td className={cn("px-4 py-3", mono)}>{e.target}</td>
                    <td className={cn("px-4 py-3 font-medium", mono)}>{e.code}</td>
                    <td className="px-4 py-3 text-muted-foreground">{e.message}</td>
                    <td className="px-4 py-3">
                      <EventState s={e.state} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="space-y-3 md:hidden">
            {list.map((e) => (
              <button
                key={e.id}
                type="button"
                onClick={() => setOpen(e.id)}
                className="block w-full rounded-lg border bg-surface p-4 text-left"
              >
                <div className="flex items-center justify-between">
                  <Severity s={e.severity} />
                  <EventState s={e.state} />
                </div>
                <p className="mt-2 font-mono text-xs font-medium">{e.code}</p>
                <p className="mt-1 text-sm">{e.message}</p>
                <p className="mt-2 font-mono text-[11px] text-muted-foreground">
                  {e.timestamp} · {e.service} · {e.target}
                </p>
              </button>
            ))}
          </div>
        </>
      )}
      <Sheet open={!!ev} onOpenChange={(o) => !o && setOpen(null)}>
        <SheetContent className="w-full overflow-y-auto sm:max-w-lg">
          {ev && (
            <>
              <SheetHeader>
                <SheetTitle className="font-mono">{ev.code}</SheetTitle>
                <SheetDescription>{ev.message}</SheetDescription>
              </SheetHeader>
              <div className="mt-6 space-y-5">
                <div className="flex items-center gap-3">
                  <Severity s={ev.severity} />
                  <EventState s={ev.state} />
                </div>
                <dl className="grid grid-cols-2 gap-4 text-sm">
                  {[
                    ["Event ID", ev.id],
                    ["Time", ev.timestamp],
                    ["Service", ev.service],
                    ["Channel / job", ev.target],
                  ].map(([a, b]) => (
                    <div key={a}>
                      <dt className="text-xs text-muted-foreground">{a}</dt>
                      <dd className="mt-1 font-mono text-xs">{b}</dd>
                    </div>
                  ))}
                </dl>
                {ev.target.startsWith("job_") && (
                  <Button variant="outline" size="sm" asChild>
                    <Link to="/admin/jobs/$id" params={{ id: ev.target }}>
                      Open job
                    </Link>
                  </Button>
                )}
                <div>
                  <p className="mb-2 text-xs font-medium text-muted-foreground">
                    Details / stack (placeholder)
                  </p>
                  <pre className="overflow-auto rounded-md bg-player p-3 font-mono text-[11px] leading-5 text-player-foreground">
                    {ev.details}
                  </pre>
                </div>
              </div>
            </>
          )}
        </SheetContent>
      </Sheet>
    </AppShell>
  );
}

/* ---------------- Public: legal, refund, contact ---------------- */
const LEGAL_LAST_UPDATED = "October 5, 2026";
// Terms, Privacy and Refund were revised for the web-only, PayPal-only scope on
// October 14, 2026; sign-up consent records that revision (LEGAL_REVISION_LABEL
// and PRIVACY_VERSION in lib/legal.ts).
// Privacy Policy: PostHog product analytics (October 21, 2026) and the
// SaveStream Android app (October 22, 2026) added (owner-approved). The
// consent version stays PRIVACY_VERSION 2026-10-14, so existing users are
// not asked to agree again.
const PRIVACY_LAST_UPDATED = "October 22, 2026";
// Terms and Refund Policy: Google Play purchases in the Android app added
// (owner-approved). The consent revision stays unchanged, so existing users
// are not asked to agree again.
const TERMS_LAST_UPDATED = "October 22, 2026";
const REFUND_LAST_UPDATED = "October 22, 2026";
const SUPPORT_EMAIL = "support@savestream.online";
const PRIVACY_EMAIL = "privacy@savestream.online";
const ABUSE_EMAIL = "abuse@savestream.online";
const COPYRIGHT_EMAIL = "copyright@savestream.online";

function MailLink({ email }: { email: string }) {
  return (
    <a href={`mailto:${email}`} className="text-primary underline underline-offset-4">
      {email}
    </a>
  );
}

function ExternalLink({ href, children }: { href: string; children: ReactNode }) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noreferrer"
      className="text-primary underline underline-offset-4"
    >
      {children}
    </a>
  );
}

function InlineLink({
  to,
  children,
}: {
  to:
    "/acceptable-use" | "/copyright" | "/privacy" | "/refund" | "/terms" | "/contact" | "/pricing";
  children: ReactNode;
}) {
  return (
    <Link to={to} className="text-primary underline underline-offset-4">
      {children}
    </Link>
  );
}

type LegalSection = { h: string; p: ReactNode };
const legalDocuments = [
  { to: "/terms", label: "Terms of Use" },
  { to: "/privacy", label: "Privacy Policy" },
  { to: "/acceptable-use", label: "Acceptable Use Policy" },
  { to: "/copyright", label: "Copyright & Takedown Policy" },
  { to: "/refund", label: "Refund Policy" },
] as const;

function legalAnchor(index: number) {
  return `section-${index + 1}`;
}

export function LegalPage({
  title,
  intro,
  sections,
  lastUpdated = LEGAL_LAST_UPDATED,
}: {
  title: string;
  intro: ReactNode;
  sections: LegalSection[];
  lastUpdated?: string;
}) {
  const { t } = usePreferences();
  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <section className="border-b bg-surface-3 pt-[72px]">
        <div className="mx-auto flex max-w-[1100px] flex-col gap-3 px-6 pb-10 pt-14">
          <span className="text-xs font-bold uppercase tracking-[.08em] text-accent-ink">
            {t("Legal")}
          </span>
          <h1 className="text-[44px] font-extrabold leading-[1.05] tracking-[-.035em]">{title}</h1>
          <p className="text-sm text-muted-foreground">Last updated {lastUpdated}.</p>
        </div>
      </section>
      <div className="mx-auto flex max-w-[1100px] flex-wrap items-start gap-12 px-6 pb-4 pt-12">
        <aside className="flex w-full flex-col gap-6 md:sticky md:top-24 md:w-[260px] md:flex-none">
          <nav
            aria-label={t("Legal documents")}
            className="flex flex-col gap-1 rounded-2xl border bg-surface p-3.5"
          >
            <span className="px-3 pb-2 pt-1 text-xs font-bold uppercase tracking-[.08em] text-accent-ink">
              {t("Legal")}
            </span>
            {legalDocuments.map((doc) => (
              <Link
                key={doc.to}
                to={doc.to}
                className="flex min-h-10 items-center rounded-[10px] px-3 text-sm font-semibold text-muted-foreground hover:bg-surface-2 hover:text-foreground"
                activeProps={{
                  className: "bg-primary-subtle text-accent-ink",
                  "aria-current": "page",
                }}
              >
                {t(doc.label)}
              </Link>
            ))}
          </nav>
          {sections.length > 3 && (
            <nav
              aria-label={t("On this page")}
              className="hidden flex-col gap-2 px-1 text-sm md:flex"
            >
              <b>{t("On this page")}</b>
              {sections.map((section, index) => (
                <a
                  key={section.h}
                  href={`#${legalAnchor(index)}`}
                  className="border-l-2 border-border pl-2.5 text-muted-foreground hover:border-primary hover:text-accent-ink"
                >
                  {index + 1}. {t(section.h)}
                </a>
              ))}
            </nav>
          )}
        </aside>
        <article className="help-prose min-w-0 max-w-[720px] flex-[999_1_560px]">
          <div className="text-muted-foreground">{intro}</div>
          {sections.map((section, index) => (
            <section key={section.h} id={legalAnchor(index)} className="scroll-mt-24">
              <h2>
                {index + 1}. {t(section.h)}
              </h2>
              <div className="space-y-3 text-[15px] leading-7 text-foreground/85">{section.p}</div>
            </section>
          ))}
        </article>
      </div>
      <PublicFooter />
    </div>
  );
}
const authorized =
  "You may only add and record livestreams from TikTok channels that you own, manage, or have explicit permission from the rights holder to record and archive.";
export function TermsPage() {
  return (
    <LegalPage
      title="Terms of Use"
      lastUpdated={TERMS_LAST_UPDATED}
      intro={
        <p>
          These Terms govern your use of SaveStream (“SaveStream”, “we”, “us”), a software and cloud
          infrastructure service for authorized livestream recording, processing, private storage,
          playback, and download. By creating an account or using SaveStream, you agree to these
          Terms.
        </p>
      }
      sections={[
        {
          h: "The service",
          p: (
            <p>
              SaveStream provides software functionality and cloud infrastructure that can monitor
              sources selected by a user and process recordings requested by that user. SaveStream
              is not a media catalog, content marketplace, publisher, or redistribution service, and
              it does not sell, license, provide, or redistribute third-party livestreams or other
              third-party content.
            </p>
          ),
        },
        {
          h: "Authorized Recording and Content Rights",
          p: (
            <>
              <p>
                You may use SaveStream only to record, process, or store content that you own, are
                authorized to access and record, or otherwise have the legal right and necessary
                permissions to use.
              </p>
              <p>
                You are solely responsible for ensuring that your use of SaveStream complies with
                applicable copyright, privacy, publicity, and other laws and with the terms and
                policies of the third-party platforms or sources from which content is accessed.
              </p>
              <p>
                SaveStream does not grant you rights to third-party content. You must stop
                monitoring or recording when your authorization ends. See our{" "}
                <InlineLink to="/acceptable-use">Acceptable Use Policy</InlineLink> and{" "}
                <InlineLink to="/copyright">Copyright &amp; Takedown Policy</InlineLink>.
              </p>
            </>
          ),
        },
        {
          h: "Technical access restrictions",
          p: (
            <p>
              You may not use SaveStream to circumvent or bypass DRM, paywalls, authentication
              requirements, encryption, subscriber-only restrictions, private-access mechanisms,
              technological protection measures, access controls, geographic restrictions, rate
              limits, or other security or platform restrictions.
            </p>
          ),
        },
        {
          h: "Your account",
          p: (
            <p>
              You must be at least 18 years old, the minimum age TikTok requires to host a LIVE, to
              create an account or use SaveStream. You are responsible for your account,
              credentials, activity, and the sources you add. Keep your credentials secure and
              contact <MailLink email={SUPPORT_EMAIL} /> if you believe your account has been
              compromised.
            </p>
          ),
        },
        {
          h: "Payments / Cloud Credits",
          p: (
            <>
              <p>
                Payments made to SaveStream are payments for software functionality, cloud
                processing capacity, storage, and related service credits. Payments do not purchase,
                license, or grant rights to any livestream, video, audio, or other third-party
                content.
              </p>
              <p>
                Purchasing credits does not grant intellectual-property rights in content processed
                or stored through SaveStream. Purchases on the website are processed by PayPal.
                Purchases in the Android app are processed by Google Play under Google Play&apos;s
                terms; refunds for app purchases are requested through Google Play.
              </p>
            </>
          ),
        },
        {
          h: "Private storage and deletion",
          p: (
            <p>
              Cloud recordings are associated with the requesting user’s account and are not made
              publicly available by SaveStream as part of a content catalog. Recordings are retained
              according to the applicable product retention period or until deleted earlier by the
              user, subject to limited security, dispute, or legal retention requirements.
            </p>
          ),
        },
        {
          h: "Prohibited infringement and redistribution",
          p: (
            <p>
              You may not use SaveStream to infringe or facilitate infringement of copyright,
              trademark, privacy, publicity, or other proprietary rights, or to unlawfully publish,
              share, resell, or redistribute third-party content.
            </p>
          ),
        },
        {
          h: "Suspension, removal, and termination",
          p: (
            <p>
              We may restrict, suspend, or terminate access to SaveStream and may restrict or remove
              hosted material when we reasonably believe the service is being used in violation of
              these Terms, applicable law, platform rules, or third-party rights. Repeated or
              serious infringement may result in account termination.
            </p>
          ),
        },
        {
          h: "Availability and third-party services",
          p: (
            <p>
              SaveStream depends on networks, hosting providers, payment providers, and third-party
              platforms we do not control. We do not guarantee that every source will remain
              technically available or that every recording request will complete without
              interruption.
            </p>
          ),
        },
        {
          h: "Disclaimer and limitation of liability",
          p: (
            <p>
              SaveStream is provided “as is” and “as available”. To the extent permitted by law,
              SaveStream is not liable for indirect, incidental, special, or consequential damages,
              or for loss of data, content, revenue, or opportunity arising from use of the service.
            </p>
          ),
        },
        {
          h: "Changes to these Terms",
          p: (
            <p>
              We may update these Terms as the service or legal requirements change. We will update
              the date above and provide additional notice where required for material changes.
            </p>
          ),
        },
        {
          h: "Contact",
          p: (
            <p>
              Questions about these Terms: <MailLink email={SUPPORT_EMAIL} />. Copyright notices:{" "}
              <MailLink email={COPYRIGHT_EMAIL} />.
            </p>
          ),
        },
      ]}
    />
  );
}
export function PrivacyPage() {
  return (
    <LegalPage
      title="Privacy Policy"
      lastUpdated={PRIVACY_LAST_UPDATED}
      intro={
        <p>
          This Privacy Policy explains how SaveStream processes personal information across our
          website, Android app, API, recording workers, and cloud storage services. Contact{" "}
          <MailLink email={PRIVACY_EMAIL} /> with privacy questions or requests.
        </p>
      }
      sections={[
        {
          h: "Information we collect",
          p: (
            <ul className="list-disc space-y-1 pl-5">
              <li>
                Account data such as email address, display name, authentication and security data.
              </li>
              <li>
                Livestream URLs, channel identifiers, source information, and monitoring settings
                you submit.
              </li>
              <li>
                Recording metadata, recording status, timestamps, duration, storage metadata, and
                media files.
              </li>
              <li>
                Billing records, purchased credits, order references, PayPal transaction references,
                and Google Play purchase tokens, order IDs, products and purchase status for
                purchases made in the Android app.
              </li>
              <li>
                Device, browser, IP address, locale, diagnostics, security logs, and audit events.
              </li>
              <li>
                In the Android app: a random app installation identifier, a push notification token,
                app version, and rewarded-ad confirmations, as described under SaveStream Android
                app.
              </li>
              <li>Support, abuse, privacy, and copyright communications you send to us.</li>
              <li>
                Product usage events, such as pages visited and steps completed, as described under
                Product analytics.
              </li>
              <li>
                Partner Program applications, including your name, email, TikTok handle, other
                channel links, niche, story, photo or logo, and consent records.
              </li>
            </ul>
          ),
        },
        {
          h: "How We Handle Recording Data",
          p: (
            <>
              <p>
                SaveStream may process livestream URLs, channel identifiers, recording metadata,
                recording status, timestamps, and media files when necessary to provide recording,
                processing, playback, download, and cloud storage functionality requested by the
                user.
              </p>
              <p>
                SaveStream does not sell users’ recordings or make them publicly available as part
                of the service. Cloud recordings are processed and stored only as necessary to
                provide the requested service, subject to the applicable retention period or until
                deleted by the user.
              </p>
            </>
          ),
        },
        {
          h: "How we use information",
          p: (
            <p>
              We use information to provide and secure the service, execute user-requested
              processing and storage, maintain account sessions, deliver notifications, process
              billing and entitlements, prevent abuse and fraud, investigate reports, provide
              support, and comply with legal obligations. We do not sell personal information or
              recordings.
            </p>
          ),
        },
        {
          h: "Service providers and disclosures",
          p: (
            <p>
              We may share the minimum necessary information with providers that help operate
              SaveStream, including Cloudflare for website infrastructure and object storage, server
              hosting providers, Brevo for transactional email, PayPal for payments on the website,
              Google (Firebase Authentication for sign-in on the website and in the Android app,
              including Google sign-in; Google Play Billing for purchases in the Android app;
              Firebase Cloud Messaging for push notifications; and Google AdMob for ads in the
              Android app), and PostHog, Inc. (United States) for product analytics. We may also
              disclose information when required by law, to protect rights or safety, or to
              investigate abuse, fraud, or infringement. Payment-card details are processed by
              PayPal or Google Play and are not stored by SaveStream.
            </p>
          ),
        },
        {
          h: "Product analytics",
          p: (
            <>
              <p>
                We use PostHog, a product analytics service hosted in the United States, to
                understand how people use SaveStream, for example which pages are visited and
                whether steps such as creating an account, verifying an email address, adding a
                channel, starting a first recording, or buying credits are completed. PostHog
                receives the page address without its query string, the referring site, browser and
                device type, an approximate location derived from your IP address, and these usage
                events. When you are signed in, events are linked to an internal account ID, not to
                your name or email address.
              </p>
              <p>
                We do not use session recording, we do not capture what you type, and we do not send
                recordings, links to recordings, or payment details to PostHog. PostHog processes
                this information on our behalf and we do not use it for advertising. Analytics is
                not loaded when your browser sends a Do Not Track or Global Privacy Control signal.
                To have analytics data about your account deleted, contact{" "}
                <MailLink email={PRIVACY_EMAIL} />.
              </p>
            </>
          ),
        },
        {
          h: "Cookies and device data",
          p: (
            <p>
              The website uses essential session and preference storage. For product analytics,
              PostHog also keeps a random identifier in your browser&apos;s local storage so that
              visits from the same browser can be counted together. The website does not use
              advertising cookies. The Android app shows ads through Google AdMob, as described
              under SaveStream Android app. You can clear or block this storage in your browser
              settings without affecting how SaveStream works.
            </p>
          ),
        },
        {
          h: "SaveStream Android app",
          p: (
            <>
              <p>
                This section applies when you use the SaveStream app for Android. The rest of this
                Policy also applies to the app. The app is a dashboard and player for your
                SaveStream account: recordings are made on SaveStream&apos;s servers, not on your
                device.
              </p>
              <p>
                <strong>Ads (Google AdMob).</strong> The app shows ads served by Google AdMob, a
                service of Google LLC. There are two kinds:
              </p>
              <ul className="list-disc space-y-1 pl-5">
                <li>
                  <strong>Rewarded ads</strong>, which you choose to watch to add free recording
                  minutes to your account. They are never shown unless you tap to watch one.
                </li>
                <li>
                  <strong>One small banner ad</strong> at the end of the Home screen. It is shown
                  only to accounts that have never bought a recording pack, and it is removed after
                  any purchase. Banner ads are never shown on the player, purchase or channel
                  verification screens.
                </li>
              </ul>
              <p>
                To serve ads, Google&apos;s Mobile Ads SDK in the app collects information from your
                device, including the Android Advertising ID, IP address, device and app
                information, and how you interact with ads. Google uses this information to deliver
                and measure ads and to prevent ad fraud and keep its services secure. SaveStream
                does not read your Advertising ID and does not send it to our servers.
              </p>
              <p>
                When you finish a rewarded ad, Google sends our server a confirmation with a
                transaction reference, the ad unit, and a reward reference that our app created for
                your account (server-side verification). We use it only to credit your minutes once
                and to prevent abuse.
              </p>
              <p>
                <strong>Personalized and non-personalized ads.</strong> If you are in the European
                Economic Area, the United Kingdom or Switzerland, the app uses Google&apos;s User
                Messaging Platform to ask for your consent before any ads are loaded. If you do not
                consent to personalized ads, Google serves non-personalized ads or limited ads
                according to your choices. If you are in a US state whose privacy laws give you the
                right to opt out of the sale or sharing of personal information or of targeted
                advertising, the app shows Google&apos;s US state privacy message, where you can opt
                out. Elsewhere, the app requests personalized ads by default, which Google selects
                using information such as your interests and activity. You can turn personalized ads
                off at any time in Settings › Ad privacy choices.
              </p>
              <p>
                <strong>Non-personalized ads</strong> are selected based on context, such as the app
                you are using and your general location. They still use device identifiers for
                frequency capping, aggregated reporting and fraud prevention. Where Google&apos;s
                consent or privacy options apply to you, you can review or change your choices at
                any time in Settings › Ad privacy choices › Review consent choices.
              </p>
              <p>
                To learn how Google uses information from apps that use its services, see{" "}
                <ExternalLink href="https://policies.google.com/technologies/partner-sites">
                  https://policies.google.com/technologies/partner-sites
                </ExternalLink>
                . Google&apos;s Privacy Policy is at{" "}
                <ExternalLink href="https://policies.google.com/privacy">
                  https://policies.google.com/privacy
                </ExternalLink>
                .
              </p>
              <p>
                <strong>Push notifications (Firebase Cloud Messaging).</strong> If you allow
                notifications, the app registers with Firebase Cloud Messaging, a Google service,
                and receives a push token. The app sends us that token together with a random app
                installation identifier, the app version and your language, so we can deliver
                notifications to the right device. We send notifications about your account, such as
                a channel you added going LIVE, a recording starting, being ready, failing, being
                missed or about to expire, a completed purchase, and low recording time.
                Notification content passes through Google&apos;s servers to reach your device. We
                do not use push notifications for advertising.
              </p>
              <p>
                <strong>Purchases (Google Play Billing).</strong> Recording packs in the app are
                sold through Google Play Billing. Google processes the payment under its own terms
                and privacy policy; SaveStream does not receive your card or other payment details.
                We receive from Google the purchase token and order ID, the product you bought, and
                the status of the purchase (for example purchased, pending, refunded or cancelled),
                and we keep a record of the order and the credits added. When you buy, the app gives
                Google a one-way hashed (SHA-256) version of your SaveStream account ID, not your
                email address, so we can confirm that the purchase belongs to your account.
              </p>
              <p>
                Refunds for purchases made in the app are requested and handled through Google Play.
                When Google tells us that a purchase was refunded or cancelled, we remove the
                related credits from your account.
              </p>
              <p>
                <strong>App installation identifier.</strong> The first time you open the app, it
                creates a random identifier for that installation and stores it securely on your
                device. It is not derived from your hardware or from the Advertising ID. We receive
                it when the app registers for notifications and when you start a rewarded ad. We use
                it to apply the daily limit on rewarded minutes per device, to detect one device
                being used with many accounts, and to prevent fraud and abuse. Uninstalling the app
                or clearing its data removes the identifier from your device.
              </p>
              <p>
                <strong>Retention for app data.</strong>
              </p>
              <ul className="list-disc space-y-1 pl-5">
                <li>
                  Push tokens and device registrations are deleted when you sign out on that device,
                  when you delete your account, or when Google reports that the token is no longer
                  valid.
                </li>
                <li>
                  Rewarded ad records (including the app installation identifier and Google&apos;s
                  transaction reference) are kept for 12 months and then deleted automatically, or
                  earlier if you delete your account.
                </li>
                <li>
                  Purchase records from Google Play are kept after account deletion for accounting,
                  tax, refund and dispute purposes, as described under Retention and deletion.
                </li>
                <li>
                  Information that Google collects through AdMob, Firebase Cloud Messaging and
                  Google Play is kept by Google under its own policies.
                </li>
              </ul>
              <p>
                <strong>Your choices in the app.</strong>
              </p>
              <ul className="list-disc space-y-1 pl-5">
                <li>
                  <strong>Ads:</strong> Settings › Ad privacy choices lets you turn personalized ads
                  on or off and, where it applies, review your consent choices. You can also reset
                  or delete your Advertising ID in your device&apos;s Android settings (Privacy ›
                  Ads, or Google › Ads, depending on the device). Buying any recording pack removes
                  the banner ad; rewarded ads are always optional.
                </li>
                <li>
                  <strong>Notifications:</strong> Settings › Notifications lets you choose which
                  notifications you receive. You can also turn off notifications for SaveStream in
                  your device&apos;s Android settings.
                </li>
                <li>
                  <strong>Account:</strong> you can delete your account in the app (Settings ›
                  Security &amp; account) or at{" "}
                  <ExternalLink href="https://savestream.online/delete-account">
                    https://savestream.online/delete-account
                  </ExternalLink>
                  .
                </li>
              </ul>
            </>
          ),
        },
        {
          h: "Retention and deletion",
          p: (
            <p>
              Recordings are kept only for the applicable retention period or until deleted sooner
              by the user. Account and operational data are retained only as long as needed for the
              service, security, fraud prevention, dispute resolution, accounting, tax, and legal
              obligations. Users can delete recordings and request account and personal-data
              deletion, subject to limited mandatory retention.
            </p>
          ),
        },
        {
          h: "Your choices and rights",
          p: (
            <p>
              Depending on your location, you may have rights to access, correct, export, object to
              certain processing of, or delete your personal information. You can use available
              account controls or contact <MailLink email={PRIVACY_EMAIL} />.
            </p>
          ),
        },
        {
          h: "Security",
          p: (
            <p>
              We use technical and organizational safeguards designed to protect account information
              and private recording data. No storage or transmission system can be guaranteed to be
              completely secure.
            </p>
          ),
        },
        {
          h: "Children",
          p: (
            <p>
              SaveStream is intended only for people who are at least 18 years old, the minimum age
              TikTok requires to host a LIVE. We do not knowingly collect personal information from
              anyone under 18. If we learn that we have, we will delete it.
            </p>
          ),
        },
        {
          h: "Creator stories and Partner Program",
          p: (
            <p>
              If you apply to the SaveStream Partner Program, we process the information you submit
              to review your application and contact you. With your written consent, we may publish
              your name, handle, image, story, and selected clips from your own recordings on the
              SaveStream website. We keep a record of that consent. You can withdraw consent at any
              time by emailing <MailLink email={PRIVACY_EMAIL} />. We will then remove your story
              from our website, but we cannot recall copies that others made before removal.
            </p>
          ),
        },
        {
          h: "Changes to this Policy",
          p: (
            <p>
              We will update the date above when this Policy changes and provide additional notice
              where required for material changes.
            </p>
          ),
        },
        {
          h: "Contact",
          p: (
            <p>
              Privacy questions and requests: <MailLink email={PRIVACY_EMAIL} />.
            </p>
          ),
        },
      ]}
    />
  );
}
export function AcceptableUsePage() {
  return (
    <LegalPage
      title="Acceptable Use Policy"
      intro={
        <p>
          SaveStream provides cloud recording, processing, and private storage infrastructure for
          lawful, authorized uses. This policy is part of our{" "}
          <InlineLink to="/terms">Terms of Use</InlineLink>.
        </p>
      }
      sections={[
        {
          h: "Authorized uses",
          p: (
            <p>
              You may use SaveStream for content you own, manage, are authorized to record, or
              otherwise have the legal right and necessary permissions to process and privately
              store.
            </p>
          ),
        },
        {
          h: "Prohibited Activities",
          p: (
            <ul className="list-disc space-y-2 pl-5">
              <li>
                Using SaveStream to copy, record, download, store, share, or distribute content
                without sufficient rights or authorization.
              </li>
              <li>
                Circumventing DRM, authentication, subscriber-only restrictions, paywalls,
                private-access mechanisms, rate limits, technical protection measures, or other
                restrictions imposed by a content owner or third-party service.
              </li>
              <li>
                Using SaveStream primarily to facilitate copyright infringement or unauthorized
                redistribution of third-party content.
              </li>
              <li>
                Using the service to harass, stalk, surveil, dox, or unlawfully collect personal
                information about another person.
              </li>
              <li>
                Uploading malware, abusing credentials, interfering with service security, evading
                quotas or enforcement, or intentionally overloading infrastructure.
              </li>
              <li>
                Using SaveStream in a way that violates applicable law or the applicable source
                platform’s terms and policies.
              </li>
            </ul>
          ),
        },
        {
          h: "No public content catalog",
          p: (
            <p>
              SaveStream is not intended to create or operate a public library of third-party media.
              Users may not use SaveStream as a redistribution, syndication, piracy, or
              content-resale service.
            </p>
          ),
        },
        {
          h: "Enforcement",
          p: (
            <p>
              We may pause processing, restrict access to stored material, remove material, suspend
              accounts, or terminate accounts when we reasonably believe this policy has been
              violated. Serious or repeated infringement may result in termination.
            </p>
          ),
        },
        {
          h: "Reporting abuse or infringement",
          p: (
            <p>
              Report suspected abuse to <MailLink email={ABUSE_EMAIL} />. Copyright owners and their
              authorized representatives should use <MailLink email={COPYRIGHT_EMAIL} /> and review
              our <InlineLink to="/copyright">Copyright &amp; Takedown Policy</InlineLink>.
            </p>
          ),
        },
      ]}
    />
  );
}
export function CopyrightPage() {
  return (
    <LegalPage
      title="Copyright & Takedown Policy"
      intro={
        <p>
          SaveStream respects intellectual-property rights and provides a process for rights holders
          to report material they believe is being processed or stored without authorization.
        </p>
      }
      sections={[
        {
          h: "Reporting Copyright Infringement",
          p: (
            <>
              <p>
                Rights holders or their authorized representatives may submit an infringement report
                to <MailLink email={COPYRIGHT_EMAIL} />.
              </p>
              <p>
                A valid report should identify the copyrighted work, the allegedly infringing
                material, sufficient information for us to locate it, contact information for the
                reporting party, and a good-faith statement regarding the claimed infringement.
              </p>
            </>
          ),
        },
        {
          h: "What to include",
          p: (
            <ul className="list-disc space-y-1 pl-5">
              <li>Your full legal name, email address, and relationship to the rights holder.</li>
              <li>
                A description or representative list of the copyrighted work claimed to be
                infringed.
              </li>
              <li>
                The SaveStream recording, account, channel, source URL, or other information
                sufficient for us to locate the material.
              </li>
              <li>
                A good-faith statement that the disputed use is not authorized by the rights holder,
                its agent, or applicable law.
              </li>
              <li>
                A statement that the information in the notice is accurate and that you are the
                rights holder or authorized to act for the rights holder.
              </li>
              <li>Your physical or electronic signature.</li>
            </ul>
          ),
        },
        {
          h: "Review and temporary restrictions",
          p: (
            <p>
              SaveStream may temporarily restrict access to or remove content while a report is
              reviewed and may preserve limited records where reasonably necessary for the review,
              dispute handling, security, or legal compliance.
            </p>
          ),
        },
        {
          h: "Account enforcement",
          p: (
            <p>
              SaveStream may terminate accounts involved in repeated or serious infringement and may
              take other proportionate action under our Terms of Use and Acceptable Use Policy.
            </p>
          ),
        },
        {
          h: "Responses and disputes",
          p: (
            <p>
              If affected users are eligible to dispute a restriction or removal, we may request
              information needed to evaluate that response. We do not adjudicate ownership disputes
              and may require parties to resolve complex claims through the appropriate legal
              process.
            </p>
          ),
        },
        {
          h: "Other rights concerns",
          p: (
            <p>
              For non-copyright abuse or unauthorized-recording concerns, contact{" "}
              <MailLink email={ABUSE_EMAIL} />.
            </p>
          ),
        },
      ]}
    />
  );
}

export function RefundPage() {
  return (
    <LegalPage
      title="Refund Policy"
      lastUpdated={REFUND_LAST_UPDATED}
      intro={<p>This policy explains how to request a refund for a SaveStream credit purchase.</p>}
      sections={[
        {
          h: "Who processes payments",
          p: (
            <>
              <p>
                Web credit purchases are processed by PayPal. Your payment receipt is issued by
                PayPal, and PayPal&apos;s terms also apply to your payment.
              </p>
              <p>
                Purchases made in the SaveStream Android app are processed by Google Play under
                Google Play&apos;s terms.
              </p>
            </>
          ),
        },
        {
          h: "How to request a refund",
          p: (
            <>
              <p>
                Email <MailLink email={SUPPORT_EMAIL} /> with:
              </p>
              <ul className="list-disc space-y-1 pl-5">
                <li>the email address of your SaveStream account;</li>
                <li>the PayPal transaction ID from your receipt;</li>
                <li>the reason for your request.</li>
              </ul>
            </>
          ),
        },
        {
          h: "How requests are handled",
          p: (
            <p>
              We review every request individually and reply by email. Refunds are not issued
              automatically. When a refund is approved, it is issued through PayPal to your original
              payment method, and the credits from that purchase are removed from your balance.
              Credits that have already been used for recordings may reduce or rule out a refund.
            </p>
          ),
        },
        {
          h: "Purchases in the Android app",
          p: (
            <p>
              Refunds for purchases made in the Android app are requested through Google Play and
              handled under Google Play&apos;s refund policies. When Google tells us that a purchase
              was refunded or cancelled, we remove the related credits from your account.
            </p>
          ),
        },
        {
          h: "Free trial credits",
          p: (
            <p>
              Free trial credits are not a purchase and cannot be refunded or exchanged for money.
            </p>
          ),
        },
        {
          h: "Contact",
          p: (
            <p>
              Billing and refund questions: <MailLink email={SUPPORT_EMAIL} />.
            </p>
          ),
        },
      ]}
    />
  );
}
export function ContactPage() {
  const { status } = useAuth();

  if (!isDemoMode && status === "authenticated") {
    return (
      <AppShell>
        <ProductionContactContent embedded />
      </AppShell>
    );
  }

  return <PublicContactPage contacts={contactChannels} />;
}

const contactChannels: ContactChannel[] = [
  {
    title: "Support",
    email: SUPPORT_EMAIL,
    body: "Questions about your account, channels, recordings, or credits. Include your account email and, for a recording, the channel name and time.",
  },
  {
    title: "Billing and refunds",
    email: SUPPORT_EMAIL,
    body: "Include the PayPal transaction ID from your receipt.",
  },
  {
    title: "Privacy",
    email: PRIVACY_EMAIL,
    body: "Requests to access, correct, or delete your personal information.",
  },
  {
    title: "Report unauthorized recording",
    email: ABUSE_EMAIL,
    body: "Tell us the channel name and why you believe it is being recorded without permission.",
  },
];

function ProductionContactContent({ embedded = false }: { embedded?: boolean }) {
  const contacts = contactChannels;
  return (
    <>
      {embedded ? (
        <PageHeader
          title="Contact us"
          subtitle="Email SaveStream support, billing, privacy, or abuse reporting without leaving your workspace."
        />
      ) : (
        <>
          <h1 className="text-3xl font-semibold">Contact us</h1>
          <p className="mt-3 text-muted-foreground">
            Email us and we usually reply within {SUPPORT_RESPONSE_TIME}. For answers to common
            questions, see{" "}
            <Link to="/help" className="text-primary underline underline-offset-4">
              Help
            </Link>
            .
          </p>
        </>
      )}
      <div className={embedded ? "grid gap-4 sm:grid-cols-2" : "mt-10 grid gap-4 sm:grid-cols-2"}>
        {contacts.map((item) => (
          <section key={item.title} className="rounded-lg border bg-surface p-5">
            <h2 className="font-medium">{item.title}</h2>
            <p className="mt-2 text-sm leading-6 text-muted-foreground">{item.body}</p>
            <p className="mt-3 text-sm">
              <MailLink email={item.email} />
            </p>
          </section>
        ))}
      </div>
    </>
  );
}
export function StatusPage() {
  return isDemoMode ? <DemoStatusPage /> : <ProductionStatusPage />;
}

function ProductionStatusPage() {
  return <PublicStatusPage />;
}

function DemoStatusPage() {
  const { t } = usePreferences();
  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <main className="mx-auto max-w-3xl px-4 pb-20 pt-28 sm:px-6">
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="text-3xl font-semibold">{t("System status")}</h1>
          <span className="rounded-md border border-warning/30 bg-warning-subtle px-2 py-1 text-xs font-semibold text-warning-foreground">
            {t("Demo data")}
          </span>
        </div>
        <p className="mt-3 text-sm leading-6 text-muted-foreground">
          {t(
            "This status page is a frontend preview. It is not connected to live monitoring or incident data.",
          )}
        </p>
        <div className="mt-6">
          <StateBanner
            tone="warning"
            title="Preview only — not live status"
            body="All values below are illustrative demo data."
          />
        </div>
        <section className="mt-8 overflow-hidden rounded-lg border bg-surface">
          {publicServices.map((service) => (
            <div key={service.name} className="border-b p-4 last:border-0">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-medium">{service.name}</p>
                    <span className="rounded border px-1.5 py-0.5 text-[10px] font-semibold text-muted-foreground">
                      {t("Demo")}
                    </span>
                  </div>
                  <p className="mt-1 text-xs text-muted-foreground">
                    {t("Illustrative service state")}
                  </p>
                </div>
                <span className="text-xs font-medium text-muted-foreground">
                  {t(service.state)}
                </span>
              </div>
              <div className="mt-3 flex gap-px opacity-50" aria-hidden>
                {Array.from({ length: 30 }).map((_, i) => (
                  <span key={i} className="h-5 flex-1 rounded-[2px] bg-muted" />
                ))}
              </div>
            </div>
          ))}
        </section>
        <section className="mt-10">
          <SectionTitle title="Incident history preview" />
          <EmptyState
            icon={ShieldCheck}
            title="Demo data"
            body="No live incident source is connected."
          />
        </section>
      </main>
      <PublicFooter />
    </div>
  );
}
