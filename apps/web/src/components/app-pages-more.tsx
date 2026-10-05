import { Link, useNavigate, useParams } from "@tanstack/react-router";
import { useEffect, useRef, useState, type ReactNode } from "react";
import {
  AlertTriangle,
  ArrowLeft,
  Bell,
  CheckCircle2,
  ChevronRight,
  CircleHelp,
  Clock3,
  Cloud,
  CreditCard,
  Download,
  FileVideo,
  Gauge,
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
import { AuthLayout, PublicFooter, PublicHeader, SectionTitle } from "@/components/app-pages";
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
import { pluralize } from "@/lib/formatters";
import { cn } from "@/lib/utils";
import { usePreferences } from "@/lib/preferences";
import { authApi, authErrorMessage } from "@/api/auth";
import type {
  AuditLogResponse,
  RecordingResponse,
  RecordingStatusValue,
} from "@/api/types";
import { useAuth } from "@/auth/auth-context";
import { isDemoMode } from "@/lib/app-config";
import { useCurrentUserData, useSessionsData } from "@/hooks/use-domain-data";
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
import {
  isAwaitingPaymentConfirmation,
  useBillingReturnOrder,
} from "@/hooks/use-billing";
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
      <AuthLayout>
        <span className="grid size-11 place-items-center rounded-full bg-primary-subtle text-primary">
          <span className="size-5 animate-spin rounded-full border-2 border-current border-t-transparent" />
        </span>
        <h1 className="mt-6 text-2xl font-semibold">{t("Verifying your email")}</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          {t("Please keep this page open while we activate your account.")}
        </p>
      </AuthLayout>
    );
  }

  return (
    <AuthLayout>
      <span className="grid size-11 place-items-center rounded-full bg-primary-subtle text-primary">
        <Mail className="size-5" />
      </span>
      <h1 className="mt-6 text-2xl font-semibold">{t("Check your email")}</h1>
      <p className="mt-2 text-sm text-muted-foreground">
        {t("We sent a verification link to your email. Open it to activate your account. The link expires in 24 hours.")}
        {email && (
          <>
            {" "}
            <b className="font-medium text-foreground">{email}</b>
          </>
        )}
      </p>
      {error && (
        <p role="alert" className="mt-4 text-sm text-destructive">
          {error}
        </p>
      )}
      <div className="mt-8 space-y-2">
        <Button
          className="w-full"
          variant="outline"
          disabled={cooldown > 0 || (!isDemoMode && !email)}
          onClick={() => {
            if (isDemoMode) {
              setCooldown(30);
              toast.success(t("Verification email sent"), { description: user.email });
              return;
            }
            if (!email) return;
            setError(null);
            void authApi
              .resendVerification(email)
              .then(() => {
                setCooldown(30);
                toast.success(t("Verification email sent"), { description: email });
              })
              .catch((resendError) => setError(authErrorMessage(resendError)));
          }}
        >
          {cooldown > 0 ? (
            <>
              {t("Resend available in")} <span className="font-mono">{cooldown}s</span>
            </>
          ) : (
            t("Resend verification email")
          )}
        </Button>
        <Button className="w-full" variant="ghost" asChild>
          <Link to="/sign-up">{t("Change email")}</Link>
        </Button>
      </div>
      <p className="mt-6 text-center text-sm text-muted-foreground">
        <Link to="/sign-in" className="font-medium text-primary">
          {t("Back to sign in")}
        </Link>
      </p>
      {isDemoMode && (
        <div className="mt-8 rounded-md border border-dashed p-3 text-xs text-muted-foreground">
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
    </AuthLayout>
  );
}

export function VerifyEmailSuccessPage() {
  const { t } = usePreferences();
  return (
    <AuthLayout>
      <SuccessState
        title="Email verified"
        body="Your account is active. Sign in to continue to SaveStream."
        action={
          isDemoMode ? (
            <>
              <Button asChild>
                <Link to="/onboarding">Continue to setup</Link>
              </Button>
              <Button variant="outline" asChild>
                <Link to="/overview">Go to dashboard</Link>
              </Button>
            </>
          ) : (
            <Button asChild className="w-full">
              <Link to="/sign-in">{t("Sign in")}</Link>
            </Button>
          )
        }
      />
    </AuthLayout>
  );
}

const authErrors = {
  expired: [
    "This link has expired",
    "Verification and reset links expire for your security. Request a new one to continue.",
  ],
  invalid: [
    "This link isn’t valid",
    "The link may have been used already or copied incorrectly. Request a new link or sign in.",
  ],
  failed: [
    "We couldn’t verify your email",
    "Something went wrong on our side. Try again in a moment — if it keeps happening, request a new link.",
  ],
} as const;
export function AuthErrorPage() {
  const { t } = usePreferences();
  const [kind, setKind] = useState<keyof typeof authErrors>("expired");
  const [errorTitle, errorBody] = authErrors[kind];
  return (
    <AuthLayout>
      <PrototypeStateBar
        value={kind}
        onChange={setKind}
        options={[
          { value: "expired", label: "Expired" },
          { value: "invalid", label: "Invalid" },
          { value: "failed", label: "Failed" },
        ]}
      />
      <span className="grid size-11 place-items-center rounded-full bg-recording-subtle text-destructive">
        <Link2Off className="size-5" />
      </span>
      <h1 className="mt-6 text-2xl font-semibold">{t(errorTitle)}</h1>
      <p className="mt-2 text-sm text-muted-foreground">{t(errorBody)}</p>
      <div className="mt-8 space-y-2">
        {kind === "failed" && (
          <Button className="w-full" onClick={() => toast("Retrying verification…")}>
            <RotateCcw />
            {t("Try again")}
          </Button>
        )}
        <Button className="w-full" variant={kind === "failed" ? "outline" : "default"} asChild>
          <Link to="/verify-email" search={{ token: "" }}>{t("Request a new link")}</Link>
        </Button>
        <Button className="w-full" variant="ghost" asChild>
          <Link to="/sign-in">{t("Back to sign in")}</Link>
        </Button>
      </div>
    </AuthLayout>
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
      <PageHeader title="Settings" subtitle="Manage your account, notifications, and security." />
      <nav aria-label="Settings sections" className="mb-6 flex gap-1 overflow-x-auto border-b">
        {settingsTabs.map((tab) => (
          <Link
            key={tab.id}
            to={tab.to}
            aria-current={section === tab.id ? "page" : undefined}
            className={cn(
              "-mb-px shrink-0 border-b-2 border-transparent px-3 pb-3 text-sm font-medium text-muted-foreground hover:text-foreground",
              section === tab.id && "border-primary text-foreground",
            )}
          >
            {t(tab.label)}
          </Link>
        ))}
      </nav>
      <div className="max-w-2xl space-y-6">
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
}: {
  title: string;
  body: string;
  children: ReactNode;
  danger?: boolean;
}) {
  const { t } = usePreferences();
  return (
    <section className={cn("rounded-lg border bg-surface p-5", danger && "border-destructive/30")}>
      <h2 className="font-medium">{t(title)}</h2>
      <p className="mb-5 mt-1 text-sm text-muted-foreground">{t(body)}</p>
      <div className="space-y-4">{children}</div>
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
  const [locale, setLocale] = useState("en");
  const [del, setDel] = useState(false);
  const [confirmText, setConfirmText] = useState("");

  useEffect(() => {
    if (!query.data) return;
    setName(query.data.display_name ?? "");
    setLocale(query.data.locale);
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
  const dirty = name !== (profile.display_name ?? "") || locale !== profile.locale;
  const initials = (profile.display_name || profile.email)
    .split(/[\s@._-]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");

  const save = () => {
    void updateProfile
      .mutateAsync({
        display_name: name.trim() || null,
        locale: locale.trim(),
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
      <Section
        title="Profile"
        body="Your display name and language. To change your email address, contact support@savestream.online."
      >
        <div className="flex items-center gap-4">
          <span className="grid size-14 place-items-center rounded-full bg-primary text-sm font-semibold text-primary-foreground">
            {initials || "SS"}
          </span>
          <div>
            <p className="text-sm font-medium">{profile.email}</p>
            <p className="text-xs text-muted-foreground">
              {profile.email_verified ? "Email verified" : "Email verification pending"}
            </p>
          </div>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <LabeledInput
            id="acc-name"
            label="Name"
            value={name}
            maxLength={160}
            onChange={(event) => setName(event.target.value)}
          />
          <LabeledInput
            id="acc-locale"
            label="Locale"
            value={locale}
            minLength={2}
            maxLength={16}
            onChange={(event) => setLocale(event.target.value)}
          />
        </div>
        <LabeledInput
          id="acc-email"
          label="Email"
          type="email"
          value={profile.email}
          readOnly
          disabled
        />
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
        <Button
          onClick={save}
          disabled={!dirty || updateProfile.isPending || locale.trim().length < 2}
        >
          {updateProfile.isPending ? "Saving…" : t("Save changes")}
        </Button>
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

  const current =
    draft ?? {
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
      <Section
        title="Email notifications"
        body="Recording notifications appear in the app. Email notifications are not available yet."
      >
        <StateBanner
          tone="info"
          icon={Mail}
          title="In-app notifications"
          body="You’ll see recording updates in the notification bell. We’ll add email notifications in a future update."
        />
      </Section>
    </>
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
        title="Sessions"
        body={`SaveStream returned ${sessions.length} session${sessions.length === 1 ? "" : "s"}. The current device is marked below.`}
      >
        {sessionsState.kind === "error" ? (
          <ErrorState
            title="Could not load sessions"
            body="SaveStream could not load active sessions."
            onRetry={() => sessionsQuery.refetch()}
          />
        ) : sessions.length ? (
          <ul className="divide-y border-y">
            {sessions.map((session) => (
              <li key={session.id} className="flex items-center gap-3 py-4">
                <Monitor className="size-5 text-muted-foreground" />
                <div className="min-w-0 flex-1">
                  <p className="flex flex-wrap items-center gap-2 text-sm font-medium">
                    <span className="truncate">
                      {session.user_agent || "Unknown browser or device"}
                    </span>
                    {session.current && (
                      <span className="rounded bg-success-subtle px-1.5 py-0.5 text-[10px] font-semibold uppercase text-success">
                        {t("This device")}
                      </span>
                    )}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {session.ip_hint || "IP unavailable"} · Last active{" "}
                    {new Date(session.last_seen_at).toLocaleString()}
                  </p>
                </div>
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
                    {t("Revoke")}
                  </Button>
                )}
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-sm text-muted-foreground">No sessions were returned.</p>
        )}

        <Button
          variant="outline"
          className="w-fit"
          onClick={() => setSignOutAll(true)}
        >
          Sign out everywhere
        </Button>
      </Section>

      <Section title="Sign-in methods" body="Ways you can sign in to SaveStream.">
        <div className="flex items-center gap-3 rounded-md border p-3">
          <KeyRound className="size-4 text-muted-foreground" />
          <div className="flex-1">
            <p className="text-sm font-medium">{t("Email and password")}</p>
            <p className="text-xs text-muted-foreground">{profile.email}</p>
          </div>
          <span className="text-xs font-medium text-success">{t("Connected")}</span>
        </div>
        <div className="flex items-center gap-3 rounded-md border p-3 opacity-70">
          <span className="grid size-4 place-items-center text-xs font-bold">G</span>
          <div className="flex-1">
            <p className="text-sm font-medium">{t("Google")}</p>
            <p className="text-xs text-muted-foreground">
              Coming soon.
            </p>
          </div>
          <span className="text-xs text-muted-foreground">Unavailable</span>
        </div>
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
        <PageHeader
          title="Notifications"
          subtitle="Updates about your recordings."
        />
        <div className="h-64 max-w-3xl animate-pulse rounded-lg border bg-muted" aria-busy="true" />
      </AppShell>
    );
  }

  if (!isDemoMode && query.isError) {
    return (
      <AppShell>
        <PageHeader
          title="Notifications"
          subtitle="Updates about your recordings."
        />
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
      <PageHeader
        title="Notifications"
        subtitle={
          isDemoMode
            ? "Recording activity, failures, and quota alerts."
            : "Updates about your recordings."
        }
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
      {!isDemoMode && (
        <div className="mb-4 max-w-3xl">
          <StateBanner
            tone="info"
            icon={Bell}
            title="Synced across devices"
            body="Your notifications and read status are the same on every device. New notifications appear automatically while this page is open."
          />
        </div>
      )}
      <div role="tablist" aria-label={t("Filter notifications")} className="mb-4 flex gap-1">
        {(["all", "unread"] as const).map((f) => (
          <Button
            key={f}
            role="tab"
            aria-selected={filter === f}
            size="sm"
            variant={filter === f ? "secondary" : "ghost"}
            onClick={() => setFilter(f)}
          >
            {f === "all" ? (
              t("All")
            ) : (
              <>
                {t("Unread")} <span className="font-mono text-xs text-muted-foreground">{unread}</span>
              </>
            )}
          </Button>
        ))}
      </div>
      {shown.length ? (
        <div className="max-w-3xl overflow-hidden rounded-lg border bg-surface">
          {shown.map((n) => (
            <NotificationItem key={n.id} notification={n} />
          ))}
        </div>
      ) : (
        <EmptyState
          icon={Bell}
          title={filter === "unread" ? "No unread notifications" : "No notifications yet"}
          body={
            filter === "unread"
              ? "You’re all caught up."
              : "We’ll notify you when recordings start, finish, or need attention."
          }
        />
      )}
      <p className="mt-4 text-xs text-muted-foreground">
        {isDemoMode ? (
          <>
            Choose which emails you receive in{" "}
            <Link
              to="/settings/notifications"
              className="text-primary underline underline-offset-4"
            >
              notification settings
            </Link>
            .
          </>
        ) : (
          <>
            Choose which recording lifecycle events create in-app notifications in{" "}
            <Link
              to="/settings/notifications"
              className="text-primary underline underline-offset-4"
            >
              notification settings
            </Link>
            .
          </>
        )}
      </p>
    </AppShell>
  );
}

/* ---------------- Billing return pages ---------------- */
export function BillingSuccessPage({ orderId = "" }: { orderId?: string }) {
  const { query, state } = useBillingReturnOrder(orderId);

  if (!orderId) {
    return (
      <AppShell>
        <div className="grid min-h-[60vh] place-items-center">
          <EmptyState
            icon={CreditCard}
            title="Payment order missing"
            body="The checkout return URL did not include a payment order. Open Billing to check your recent orders."
            action={
              <Button asChild>
                <Link to="/billing">View billing</Link>
              </Button>
            }
          />
        </div>
      </AppShell>
    );
  }

  if (state.kind === "loading") {
    return (
      <AppShell>
        <div className="grid min-h-[60vh] place-items-center">
          <div className="w-full max-w-md rounded-lg border bg-surface p-6 text-center">
            <span className="mx-auto block size-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            <h1 className="mt-5 text-xl font-semibold">Checking payment status…</h1>
            <p className="mt-2 text-sm text-muted-foreground">
              We’re confirming your payment with Lemon Squeezy.
            </p>
          </div>
        </div>
      </AppShell>
    );
  }

  if (state.kind === "error" || !query.data) {
    return (
      <AppShell>
        <div className="grid min-h-[60vh] place-items-center">
          <ErrorState
            title="Could not confirm payment"
            body="We couldn’t confirm your payment yet. Please try again; if you were charged, your credits will be added once the payment is confirmed."
            onRetry={() => query.refetch()}
          />
        </div>
      </AppShell>
    );
  }

  const order = query.data;

  if (isAwaitingPaymentConfirmation(order.status)) {
    return (
      <AppShell>
        <div className="mx-auto grid min-h-[60vh] max-w-xl place-items-center">
          <div className="w-full space-y-5">
            <StateBanner
              tone="info"
              icon={Clock3}
              title="Payment is being confirmed"
              body="Your payment is still being confirmed. Credits are added as soon as Lemon Squeezy confirms it, usually within a minute."
              action={
                <Button size="sm" variant="outline" onClick={() => void query.refetch()}>
                  <RotateCcw />
                  Check now
                </Button>
              }
            />
            <div className="flex flex-wrap justify-center gap-2">
              <Button asChild>
                <Link to="/billing">View billing</Link>
              </Button>
              <Button variant="outline" asChild>
                <a href={`/billing/canceled?order_id=${encodeURIComponent(order.id)}`}>
                  I left checkout
                </a>
              </Button>
            </div>
          </div>
        </div>
      </AppShell>
    );
  }

  if (order.status === "paid") {
    return (
      <AppShell>
        <div className="grid min-h-[60vh] place-items-center">
          <SuccessState
            title={`${pluralize(order.credits, "credit")} added`}
            body="Your payment is confirmed and the credits are in your balance."
            action={
              <>
                <Button asChild>
                  <Link to="/usage">View credits</Link>
                </Button>
                <Button variant="outline" asChild>
                  <Link to="/billing">View billing</Link>
                </Button>
              </>
            }
          />
        </div>
      </AppShell>
    );
  }

  const refunded = order.status === "partially_refunded" || order.status === "refunded";
  return (
    <AppShell>
      <div className="mx-auto grid min-h-[60vh] max-w-xl place-items-center">
        <div className="w-full space-y-5">
          <StateBanner
            tone={refunded ? "info" : "error"}
            icon={refunded ? CreditCard : XCircle}
            title={refunded ? "Payment has a refund status" : "Payment was not completed"}
            body={
              refunded
                ? `This purchase is ${paymentReturnStatusLabel(order.status)}. Your current balance is shown in Usage.`
                : `This purchase is ${paymentReturnStatusLabel(order.status)}. No credits were added.`
            }
          />
          <div className="flex justify-center">
            <Button asChild>
              <Link to="/billing">Back to billing</Link>
            </Button>
          </div>
        </div>
      </div>
    </AppShell>
  );
}

function paymentReturnStatusLabel(status: string) {
  return status.replaceAll("_", " ");
}

export function BillingCanceledPage({ orderId = "" }: { orderId?: string }) {
  const { query, state } = useBillingReturnOrder(orderId);

  if (!orderId) {
    return (
      <AppShell>
        <div className="grid min-h-[60vh] place-items-center text-center">
          <div>
            <span className="mx-auto grid size-12 place-items-center rounded-full bg-muted text-muted-foreground">
              <XCircle className="size-6" />
            </span>
            <h1 className="mt-5 text-2xl font-semibold">Checkout closed</h1>
            <p className="mx-auto mt-2 max-w-md text-sm text-muted-foreground">
              You left checkout before completing a purchase. No payment was taken.
            </p>
            <Button className="mt-7" asChild>
              <Link to="/billing">Back to billing</Link>
            </Button>
          </div>
        </div>
      </AppShell>
    );
  }

  if (state.kind === "loading") {
    return (
      <AppShell>
        <div className="grid min-h-[60vh] place-items-center">
          <div className="w-full max-w-md rounded-lg border bg-surface p-6 text-center">
            <span className="mx-auto block size-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            <p className="mt-4 text-sm text-muted-foreground">
              Checking your payment status…
            </p>
          </div>
        </div>
      </AppShell>
    );
  }

  if (state.kind === "error" || !query.data) {
    return (
      <AppShell>
        <div className="grid min-h-[60vh] place-items-center">
          <ErrorState
            title="Could not check payment order"
            body="Open Billing to review the order again. SaveStream will not infer cancellation or payment from this page alone."
            onRetry={() => query.refetch()}
          />
        </div>
      </AppShell>
    );
  }

  const order = query.data;
  const paid = order.status === "paid";

  return (
    <AppShell>
      <div className="mx-auto grid min-h-[60vh] max-w-xl place-items-center">
        <div className="w-full space-y-5">
          <StateBanner
            tone={paid ? "success" : isAwaitingPaymentConfirmation(order.status) ? "warning" : "info"}
            icon={paid ? CheckCircle2 : XCircle}
            title={
              paid
                ? "Payment was already confirmed"
                : isAwaitingPaymentConfirmation(order.status)
                  ? "Checkout left before confirmation"
                  : "Checkout is not active"
            }
            body={
              paid
                ? "This purchase was paid. The credits are in your balance."
                : isAwaitingPaymentConfirmation(order.status)
                  ? "This purchase is still pending. If you completed payment, the credits will be added once it is confirmed; check Billing again in a minute."
                  : `This purchase is ${paymentReturnStatusLabel(order.status)}.`
            }
          />
          <div className="flex justify-center gap-2">
            <Button asChild>
              <Link to="/billing">Back to billing</Link>
            </Button>
            {isAwaitingPaymentConfirmation(order.status) && (
              <Button variant="outline" onClick={() => void query.refetch()}>
                <RotateCcw />
                Check status
              </Button>
            )}
          </div>
        </div>
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
    <span className={cn("inline-flex rounded-md px-2 py-1 text-xs font-medium", className)}>
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

      <div className="grid overflow-hidden rounded-lg border sm:grid-cols-2 xl:grid-cols-4">
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
          label="Recent failures"
          value={String(data.failed_recordings_recent)}
          detail="Backend failure window"
          icon={AlertTriangle}
        />
        <StatCard
          label="Paused error watches"
          value={String(data.paused_error_watches)}
          detail="Watches paused after errors"
          icon={ShieldCheck}
        />
      </div>

      <section className="mt-8 rounded-lg border bg-surface p-5">
        <h2 className="font-medium">Operational boundaries</h2>
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
                    <th key={heading} className="px-4 py-2 font-medium">
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
                      {recording.started_at
                        ? new Date(recording.started_at).toLocaleString()
                        : "—"}
                    </td>
                    <td className="px-4 py-3 font-mono">
                      {formatAdminDuration(recording.duration_seconds)}
                    </td>
                    <td className="px-4 py-3 font-mono">
                      {formatAdminBytes(recording.bytes_recorded)}
                    </td>
                    <td className="px-4 py-3 font-mono">
                      {recording.actual_cost === null
                        ? "—"
                        : `${recording.actual_cost} credits`}
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
                    <dd className="mt-1 font-mono">
                      {formatAdminBytes(recording.bytes_recorded)}
                    </dd>
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
        title={item.id}
        subtitle={adminSourceLabel(item)}
        action={
          <div className="flex gap-2">
            <Button
              variant="outline"
              disabled={recording.isFetching}
              onClick={() => void recording.refetch()}
            >
              <RotateCcw />
              Refresh
            </Button>
            {item.actions.can_retry && (
              <Button
                variant="outline"
                disabled={retry.isPending}
                onClick={() => setConfirmRetry(true)}
              >
                <RotateCcw />
                Retry recording
              </Button>
            )}
          </div>
        }
      />

      <div className="mb-6 flex flex-wrap items-center gap-3">
        <AdminRecordingStatusPill status={item.status} />
        <span className="text-xs text-muted-foreground">
          Active records refresh every 5 seconds.
        </span>
      </div>

      {item.error && (
        <div className="mb-6 rounded-lg border border-destructive/30 bg-recording-subtle p-4">
          <p className="text-sm font-medium text-destructive">{item.error.code}</p>
          <p className="mt-2 text-sm">{item.error.message}</p>
          <p className="mt-2 text-xs text-muted-foreground">
            Retryable: {item.error.retryable ? "yes" : "no"}
          </p>
        </div>
      )}

      <section className="rounded-lg border bg-surface p-5">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h2 className="font-medium">Backend recording state</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Only fields returned by the admin recording API are shown.
            </p>
          </div>
        </div>
        <dl className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {fields.map(([label, value]) => (
            <div key={label} className="min-w-0">
              <dt className="text-xs text-muted-foreground">{label}</dt>
              <dd className="mt-1 break-words font-mono text-xs">{value}</dd>
            </div>
          ))}
        </dl>
      </section>

      <section className="mt-6 rounded-lg border bg-surface p-5">
        <h2 className="font-medium">Actions exposed by backend</h2>
        <p className="mt-2 text-sm text-muted-foreground">
          Retry is available only when the recording response says can_retry. The admin API does
          not expose a browser action to mark a job failed, kill a worker, or edit hidden job state.
        </p>
      </section>

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
        <div className="mb-6 grid overflow-hidden rounded-lg border sm:grid-cols-2 xl:grid-cols-4">
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
          <div className="hidden overflow-x-auto rounded-lg border bg-surface md:block">
            <table className="w-full min-w-[900px] text-xs">
              <thead className="bg-surface-subtle text-left text-[10px] uppercase text-muted-foreground">
                <tr>
                  {["Time", "Action", "Resource", "Actor", "Request ID"].map((heading) => (
                    <th key={heading} className="px-4 py-2 font-medium">
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
                    className="cursor-pointer border-t hover:bg-accent focus-visible:bg-accent focus-visible:outline-none"
                  >
                    <td className="whitespace-nowrap px-4 py-3 font-mono">
                      {new Date(entry.created_at).toLocaleString()}
                    </td>
                    <td className="px-4 py-3 font-mono font-medium">{entry.action}</td>
                    <td className="px-4 py-3 font-mono">{adminAuditResource(entry)}</td>
                    <td className="max-w-44 truncate px-4 py-3 font-mono">
                      {entry.actor_user_id ?? "system"}
                    </td>
                    <td className="max-w-44 truncate px-4 py-3 font-mono text-muted-foreground">
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
                className="block w-full rounded-lg border bg-surface p-4 text-left"
              >
                <p className="font-mono text-xs font-medium">{entry.action}</p>
                <p className="mt-2 text-xs text-muted-foreground">
                  {adminAuditResource(entry)}
                </p>
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
                <SheetTitle className="font-mono">{selected.action}</SheetTitle>
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
                  <pre className="max-h-80 overflow-auto rounded-md bg-player p-3 font-mono text-[11px] leading-5 text-player-foreground">
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
  to: "/acceptable-use" | "/copyright" | "/privacy" | "/refund" | "/terms" | "/contact" | "/pricing";
  children: ReactNode;
}) {
  return (
    <Link to={to} className="text-primary underline underline-offset-4">
      {children}
    </Link>
  );
}

type LegalSection = { h: string; p: ReactNode };
export function LegalPage({
  title,
  intro,
  sections,
}: {
  title: string;
  intro: ReactNode;
  sections: LegalSection[];
}) {
  const { t } = usePreferences();
  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <main className="mx-auto max-w-3xl px-4 pb-20 pt-28 sm:px-6">
        <p className="text-xs text-muted-foreground">Last updated {LEGAL_LAST_UPDATED}</p>
        <h1 className="mt-2 text-3xl font-semibold">{title}</h1>
        <div className="mt-3 text-muted-foreground">{intro}</div>
        <div className="mt-10 space-y-8">
          {sections.map((s, i) => (
            <section key={s.h}>
              <h2 className="text-lg font-semibold">
                <span className="mr-2 font-mono text-sm text-muted-foreground">{i + 1}.</span>
                {t(s.h)}
              </h2>
              <div className="mt-2 space-y-2 text-sm leading-7 text-muted-foreground">{s.p}</div>
            </section>
          ))}
        </div>
      </main>
      <PublicFooter />
    </div>
  );
}
const authorized =
  "You may only add and record livestreams from TikTok channels that you own, manage, or have explicit permission from the rights holder to record and archive.";
export function TermsPage() {
  const { t } = usePreferences();
  return (
    <LegalPage
      title="Terms of Use"
      intro={
        <p>
          These Terms govern your use of SaveStream (“SaveStream”, “we”, “us”), a software and cloud
          infrastructure service for authorized livestream recording, processing, private storage,
          playback, and download. By creating an account or using SaveStream, you agree to these Terms.
        </p>
      }
      sections={[
        {
          h: "The service",
          p: (
            <p>
              SaveStream provides software functionality and cloud infrastructure that can monitor
              sources selected by a user and process recordings requested by that user. SaveStream is
              not a media catalog, content marketplace, publisher, or redistribution service, and it
              does not sell, license, provide, or redistribute third-party livestreams or other
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
                SaveStream does not grant you rights to third-party content. You must stop monitoring
                or recording when your authorization ends. See our{" "}
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
              You are responsible for your account, credentials, activity, and the sources you add.
              Keep your credentials secure and contact <MailLink email={SUPPORT_EMAIL} /> if you
              believe your account has been compromised.
            </p>
          ),
        },
        {
          h: "Payments / Cloud Credits",
          p: (
            <>
              <p>
                Payments made to SaveStream are payments for software functionality, cloud processing
                capacity, storage, and related service credits. Payments do not purchase, license, or
                grant rights to any livestream, video, audio, or other third-party content.
              </p>
              <p>
                Purchasing credits does not grant intellectual-property rights in content processed
                or stored through SaveStream. Web checkout may be processed by a third-party payment
                provider or Merchant of Record identified at checkout. Mobile purchases are processed
                by the App Store or Google Play.
              </p>
            </>
          ),
        },
        {
          h: t("Free mobile advertising"),
          p: (
            <p>
              The Free mobile app may show banner and rewarded ads. Advertising supports the local
              app experience and does not grant rights to any third-party content.
            </p>
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
              these Terms, applicable law, platform rules, or third-party rights. Repeated or serious
              infringement may result in account termination.
            </p>
          ),
        },
        {
          h: "Availability and third-party services",
          p: (
            <p>
              SaveStream depends on networks, hosting providers, app stores, payment providers, and
              third-party platforms we do not control. We do not guarantee that every source will
              remain technically available or that every recording request will complete without
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
              Questions about these Terms: <MailLink email={SUPPORT_EMAIL} />. Copyright notices:
              {" "}<MailLink email={COPYRIGHT_EMAIL} />.
            </p>
          ),
        },
      ]}
    />
  );
}
export function PrivacyPage() {
  const { t } = usePreferences();
  return (
    <LegalPage
      title="Privacy Policy"
      intro={
        <p>
          This Privacy Policy explains how SaveStream processes personal information across our
          website, mobile apps, API, recording workers, and cloud storage services. Contact{" "}
          <MailLink email={PRIVACY_EMAIL} /> with privacy questions or requests.
        </p>
      }
      sections={[
        {
          h: "Information we collect",
          p: (
            <ul className="list-disc space-y-1 pl-5">
              <li>Account data such as email address, display name, authentication and security data.</li>
              <li>Livestream URLs, channel identifiers, source information, and monitoring settings you submit.</li>
              <li>Recording metadata, recording status, timestamps, duration, storage metadata, and media files.</li>
              <li>Billing records, purchased credits, order references, and app-store transaction references.</li>
              <li>Device, browser, IP address, push token, locale, diagnostics, security logs, and audit events.</li>
              <li>Support, abuse, privacy, and copyright communications you send to us.</li>
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
                processing, playback, download, and cloud storage functionality requested by the user.
              </p>
              <p>
                SaveStream does not sell users’ recordings or make them publicly available as part of
                the service. Cloud recordings are processed and stored only as necessary to provide
                the requested service, subject to the applicable retention period or until deleted by
                the user.
              </p>
            </>
          ),
        },
        {
          h: "How we use information",
          p: (
            <p>
              We use information to provide and secure the service, execute user-requested processing
              and storage, maintain account sessions, deliver notifications, process billing and
              entitlements, prevent abuse and fraud, investigate reports, provide support, and comply
              with legal obligations. We do not sell personal information or recordings.
            </p>
          ),
        },
        {
          h: "Service providers and disclosures",
          p: (
            <p>
              We may share the minimum necessary information with providers that help operate
              SaveStream, including Cloudflare for website infrastructure and object storage, VNPT
              for server infrastructure, Brevo for transactional email, Apple App Store or Google
              Play for mobile purchases, and the web payment provider or Merchant of Record
              identified at checkout. We may also disclose information when required by law, to
              protect rights or safety, or to investigate abuse, fraud, or infringement. Payment-card
              details are processed by the applicable payment provider and are not stored by
              SaveStream in full.
            </p>
          ),
        },
        {
          h: "Cookies, device data, and advertising",
          p: (
            <p>
              The website uses essential session and preference storage. Mobile devices may register
              a push token, platform, and locale so SaveStream can deliver notifications and open the
              correct screen.
            </p>
          ),
        },
        {
          h: t("Advertising in the Free mobile app"),
          p: (
            <p>
              The Free mobile app may use advertising services for banner and rewarded ads. Those
              services may receive device or advertising identifiers needed to deliver and verify ads,
              subject to device settings and applicable law.
            </p>
          ),
        },
        {
          h: "App-store purchases",
          p: (
            <p>
              Apple App Store or Google Play may process one-time mobile purchases, transaction
              identifiers, and store-managed refunds. SaveStream does not receive your full payment
              card number from those stores.
            </p>
          ),
        },
        {
          h: "Retention and deletion",
          p: (
            <p>
              Recordings are kept only for the applicable retention period or until deleted sooner by
              the user. Account and operational data are retained only as long as needed for the
              service, security, fraud prevention, dispute resolution, accounting, tax, and legal
              obligations. Users can delete recordings and request account and personal-data deletion,
              subject to limited mandatory retention.
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
          p: <p>SaveStream is not intended for children and we do not knowingly collect their data.</p>,
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
          p: <p>Privacy questions and requests: <MailLink email={PRIVACY_EMAIL} />.</p>,
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
              otherwise have the legal right and necessary permissions to process and privately store.
            </p>
          ),
        },
        {
          h: "Prohibited Activities",
          p: (
            <ul className="list-disc space-y-2 pl-5">
              <li>Using SaveStream to copy, record, download, store, share, or distribute content without sufficient rights or authorization.</li>
              <li>Circumventing DRM, authentication, subscriber-only restrictions, paywalls, private-access mechanisms, rate limits, technical protection measures, or other restrictions imposed by a content owner or third-party service.</li>
              <li>Using SaveStream primarily to facilitate copyright infringement or unauthorized redistribution of third-party content.</li>
              <li>Using the service to harass, stalk, surveil, dox, or unlawfully collect personal information about another person.</li>
              <li>Uploading malware, abusing credentials, interfering with service security, evading quotas or enforcement, or intentionally overloading infrastructure.</li>
              <li>Using SaveStream in a way that violates applicable law or the applicable source platform’s terms and policies.</li>
            </ul>
          ),
        },
        {
          h: "No public content catalog",
          p: (
            <p>
              SaveStream is not intended to create or operate a public library of third-party media.
              Users may not use SaveStream as a redistribution, syndication, piracy, or content-resale service.
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
              <li>A description or representative list of the copyrighted work claimed to be infringed.</li>
              <li>The SaveStream recording, account, channel, source URL, or other information sufficient for us to locate the material.</li>
              <li>A good-faith statement that the disputed use is not authorized by the rights holder, its agent, or applicable law.</li>
              <li>A statement that the information in the notice is accurate and that you are the rights holder or authorized to act for the rights holder.</li>
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
              and may require parties to resolve complex claims through the appropriate legal process.
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
      intro={<p>This policy explains how to request a refund for a SaveStream credit purchase.</p>}
      sections={[
        {
          h: "Who processes payments",
          p: (
            <p>
              Credit purchases are processed by Lemon Squeezy, which acts as our reseller and
              Merchant of Record. Your order receipt comes from Lemon Squeezy, and the{" "}
              <ExternalLink href="https://www.lemonsqueezy.com/buyer-terms">
                Lemon Squeezy buyer terms
              </ExternalLink>{" "}
              also apply to your purchase.
            </p>
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
                <li>the order number from your Lemon Squeezy receipt;</li>
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
              automatically. When a refund is approved, it is issued through Lemon Squeezy to your
              original payment method, and the credits from that purchase are removed from your
              balance. Credits that have already been used for recordings may reduce or rule out a
              refund.
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
  const contacts: { title: string; email: string; body: string }[] = [
    {
      title: "Support",
      email: SUPPORT_EMAIL,
      body: "Questions about your account, channels, recordings, or credits. Include your account email and, for a recording, the channel name and time.",
    },
    {
      title: "Billing and refunds",
      email: SUPPORT_EMAIL,
      body: "Include the order number from your Lemon Squeezy receipt.",
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
  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <main className="mx-auto max-w-3xl px-4 pb-20 pt-28 sm:px-6">
        <h1 className="text-3xl font-semibold">Contact us</h1>
        <p className="mt-3 text-muted-foreground">
          Email us and we will get back to you. For answers to common questions, see{" "}
          <Link to="/help" className="text-primary underline underline-offset-4">
            Help
          </Link>
          .
        </p>
        <div className="mt-10 grid gap-4 sm:grid-cols-2">
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
      </main>
      <PublicFooter />
    </div>
  );
}
export function StatusPage() {
  return isDemoMode ? <DemoStatusPage /> : <ProductionStatusPage />;
}

function ProductionStatusPage() {
  const { t } = usePreferences();
  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <main className="mx-auto max-w-3xl px-4 pb-20 pt-28 sm:px-6">
        <h1 className="text-3xl font-semibold">{t("System status")}</h1>
        <p className="mt-3 text-sm leading-6 text-muted-foreground">
          SaveStream does not currently publish a public live incident feed from the production backend.
        </p>
        <div className="mt-6">
          <StateBanner
            tone="info"
            icon={ShieldCheck}
            title="Live public status is not available yet"
            body="This page deliberately does not display illustrative service health, fake uptime bars, or synthetic incidents in production."
          />
        </div>
        <section className="mt-8 rounded-lg border bg-surface p-5">
          <h2 className="font-medium">What is available</h2>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            Authenticated product pages report request errors directly from the SaveStream API. Admin operational data remains restricted to authorized admin accounts.
          </p>
        </section>
      </main>
      <PublicFooter />
    </div>
  );
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
          {t("This status page is a frontend preview. It is not connected to live monitoring or incident data.")}
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
                  <p className="mt-1 text-xs text-muted-foreground">{t("Illustrative service state")}</p>
                </div>
                <span className="text-xs font-medium text-muted-foreground">{t(service.state)}</span>
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
          <EmptyState icon={ShieldCheck} title="Demo data" body="No live incident source is connected." />
        </section>
      </main>
      <PublicFooter />
    </div>
  );
}

/* ---------------- Help ---------------- */
const demoHelpTopics: { id: string; icon: typeof Cloud; title: string; body: string }[] = [
  {
    id: "getting-started",
    icon: Radio,
    title: "Getting started",
    body: "Create an account, add an authorized TikTok channel, and leave monitoring enabled. Recording starts automatically when the channel goes live.",
  },
  {
    id: "cloud-monitoring",
    icon: Cloud,
    title: "How cloud monitoring works",
    body: "SaveStream checks enabled channels from cloud infrastructure. Nothing needs to keep running in your browser.",
  },
  {
    id: "browser-closed",
    icon: Monitor,
    title: "What happens if I close my browser or computer?",
    body: "In the product flow, monitoring and recording continue in the cloud. This frontend demo does not connect to a real recorder.",
  },
  {
    id: "lifecycle",
    icon: FileVideo,
    title: "Recording lifecycle",
    body: "The UI models waiting, recording, processing, ready, partial, failed, expiring, and expired states so the future API can map to clear user feedback.",
  },
  {
    id: "quotas",
    icon: Gauge,
    title: "Quotas",
    body: "Monthly limits include recording time, monitored channels, simultaneous recordings, download bandwidth, and retention. The current frontend values come from one plan catalog.",
  },
  {
    id: "retention",
    icon: Clock3,
    title: "Retention",
    body: "Recordings are shown with an expiry state based on the selected plan. Download anything you are authorized to keep before its retention period ends.",
  },
  {
    id: "troubleshooting",
    icon: AlertTriangle,
    title: "Failed recording troubleshooting",
    body: "Failed and partial recordings should explain what was kept, whether retry is available, and what the user can do next.",
  },
  {
    id: "authorized",
    icon: ShieldCheck,
    title: "Authorized recording policy",
    body: "Only add channels you own, manage, or have explicit permission to record and archive.",
  },
];

const productionHelpTopics: { id: string; icon: typeof Cloud; title: string; body: ReactNode }[] = [
  {
    id: "getting-started",
    icon: Radio,
    title: "Getting started",
    body: "Create an account, verify your email, and add a TikTok channel you own, manage, or have permission to record. SaveStream starts watching it right away.",
  },
  {
    id: "cloud-monitoring",
    icon: Cloud,
    title: "How monitoring works",
    body: "SaveStream checks your channels from the cloud. When one goes live, recording starts automatically, so you can close your browser or turn off your computer.",
  },
  {
    id: "recordings",
    icon: FileVideo,
    title: "Watching and downloading recordings",
    body: "When a livestream ends, the recording is processed and appears in Recordings, ready to watch in the browser or download. You can also stop a recording early.",
  },
  {
    id: "credits",
    icon: Gauge,
    title: "Credits",
    body: (
      <>
        Recording time is paid with credits, bought once and never expiring. New accounts get free
        trial credits after verifying their email. A recording runs until the livestream ends or
        your credits run out. See{" "}
        <Link to="/pricing" className="text-primary underline underline-offset-4">
          Pricing
        </Link>{" "}
        for packages and the current rate.
      </>
    ),
  },
  {
    id: "retention",
    icon: Clock3,
    title: "How long are recordings kept?",
    body: "Finished recordings are stored for 30 days after you buy credits, or 7 days on the free trial, then deleted automatically. Each recording shows its expiry date. Download anything you want to keep longer.",
  },
  {
    id: "troubleshooting",
    icon: AlertTriangle,
    title: "If a recording fails",
    body: "Open the recording to see what happened. When it can be retried, you will see a Retry button. Failed recordings do not use your credits.",
  },
  {
    id: "authorized",
    icon: ShieldCheck,
    title: "Authorized recording policy",
    body: "Only add channels you own, manage, or have explicit permission to record and archive.",
  },
];

export function HelpPage() {
  return isDemoMode ? <DemoHelpPage /> : <PublicHelpPage />;
}

function PublicHelpPage() {
  const { t } = usePreferences();
  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <main className="mx-auto max-w-5xl px-4 pb-20 pt-28 sm:px-6">
        <h1 className="text-3xl font-semibold">{t("Help")}</h1>
        <p className="mt-3 text-muted-foreground">
          {t("Guidance for monitoring and recording authorized TikTok channels.")}
        </p>
        <div className="mt-10 grid gap-4 lg:grid-cols-2">
          {productionHelpTopics.map((topic) => {
            const I = topic.icon;
            return (
              <section
                key={topic.id}
                id={topic.id}
                className="scroll-mt-24 rounded-lg border bg-surface p-5"
              >
                <div className="flex items-center gap-2">
                  <I className="size-4 text-primary" />
                  <h2 className="font-medium">{t(topic.title)}</h2>
                </div>
                <div className="mt-3 text-sm leading-6 text-muted-foreground">
                  {typeof topic.body === "string" ? t(topic.body) : topic.body}
                </div>
              </section>
            );
          })}
        </div>
        <section
          id="contact"
          className="mt-8 flex flex-col gap-4 rounded-lg border bg-surface-subtle p-5 sm:flex-row sm:items-center"
        >
          <CircleHelp className="size-5 text-primary" />
          <div className="flex-1">
            <h2 className="font-medium">{t("Still need help?")}</h2>
            <p className="text-sm text-muted-foreground">
              Email <MailLink email={SUPPORT_EMAIL} /> and we will get back to you.
            </p>
          </div>
          <Button variant="outline" asChild>
            <Link to="/contact">{t("Contact support")}</Link>
          </Button>
        </section>
      </main>
      <PublicFooter />
    </div>
  );
}

function DemoHelpPage() {
  const { t } = usePreferences();
  const [contact, setContact] = useState(false);
  const [msg, setMsg] = useState("");
  const helpTopics = demoHelpTopics;
  return (
    <AppShell>
      <PageHeader
        title="Help"
        subtitle="Guidance for monitoring and recording authorized TikTok channels."
        action={
          <Button variant="outline" onClick={() => setContact(true)}>
            <LifeBuoy />
            {t("Contact support")}
          </Button>
        }
      />
      <nav aria-label={t("Help topics")} className="mb-6 flex gap-2 overflow-x-auto pb-1">
        {helpTopics.map((topic) => (
          <a
            key={topic.id}
            href={`#${topic.id}`}
            className="shrink-0 rounded-md border bg-surface px-3 py-1.5 text-xs font-medium text-muted-foreground hover:text-foreground"
          >
            {t(topic.title === "What happens if I close my browser or computer?" ? "Browser closed" : topic.title)}
          </a>
        ))}
      </nav>
      <div className="grid gap-4 lg:grid-cols-2">
        {helpTopics.map((topic) => {
          const I = topic.icon;
          return (
            <section key={topic.id} id={topic.id} className="scroll-mt-24 rounded-lg border bg-surface p-5">
              <div className="flex items-center gap-2">
                <I className="size-4 text-primary" />
                <h2 className="font-medium">{t(topic.title)}</h2>
              </div>
              <div className="mt-3 space-y-2 text-sm leading-6 text-muted-foreground">{t(topic.body)}</div>
            </section>
          );
        })}
      </div>
      <section
        id="contact"
        className="mt-8 scroll-mt-24 flex flex-col gap-4 rounded-lg border bg-surface-subtle p-5 sm:flex-row sm:items-center"
      >
        <CircleHelp className="size-5 text-primary" />
        <div className="flex-1">
          <h2 className="font-medium">{t("Still need help?")}</h2>
          <p className="text-sm text-muted-foreground">
            {t("This demo does not send support messages.")}
          </p>
        </div>
        <Button onClick={() => setContact(true)}>{t("Contact support")}</Button>
      </section>
      <Dialog open={contact} onOpenChange={setContact}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("Contact support")}</DialogTitle>
            <DialogDescription>{t("This demo does not send support messages.")}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <label htmlFor="sup-subject" className="text-sm font-medium">
                {t("Subject")}
              </label>
              <Input
                id="sup-subject"
                className="mt-2"
                placeholder={t("e.g. Recording failed for @norashop")}
              />
            </div>
            <div>
              <label htmlFor="sup-msg" className="text-sm font-medium">
                {t("Message")}
              </label>
              <Textarea
                id="sup-msg"
                className="mt-2"
                rows={5}
                value={msg}
                onChange={(e) => setMsg(e.target.value)}
                placeholder={t("What happened, and when?")}
              />
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setContact(false)}>
              {t("Cancel")}
            </Button>
            <Button
              disabled={!msg.trim()}
              onClick={() => {
                setContact(false);
                setMsg("");
                toast.success(t("Demo function"), {
                  description: t("This demo does not send support messages."),
                });
              }}
            >
              {t("Send message")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </AppShell>
  );
}