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
import { notificationStore, useNotifications } from "@/lib/notification-store";
import { cn } from "@/lib/utils";
import { usePreferences } from "@/lib/preferences";
import { authApi, authErrorMessage } from "@/api/auth";
import { isDemoMode } from "@/lib/app-config";
import {
  isAwaitingPaymentConfirmation,
  useBillingReturnOrder,
} from "@/hooks/use-billing";

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
        body="All channels, recordings, and billing history will be permanently removed. Any active subscription will be canceled."
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
  ["quota", "Quota warning", "At 80% and 100% of your monthly recording hours or downloads."],
  [
    "expiry",
    "Retention / expiration warning",
    "Before a recording is removed at the end of its retention period.",
  ],
] as const;
function NotificationSettings() {
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
        <PasswordField id="sec-cur" label="Current password" value={cur} onChange={setCur} />
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
  const list = useNotifications();
  const [filter, setFilter] = useState<"all" | "unread">("all");
  const shown = filter === "all" ? list : list.filter((n) => !n.read);
  const unread = list.filter((n) => !n.read).length;
  return (
    <AppShell>
      <PageHeader
        title="Notifications"
        subtitle="Recording activity, failures, and quota alerts."
        action={
          <Button
            variant="outline"
            disabled={!unread}
            onClick={() => {
              notificationStore.markAllRead();
              toast.success(t("All notifications marked as read"));
            }}
          >
            {t("Mark all as read")}
          </Button>
        }
      />
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
          body={filter === "unread" ? "You’re all caught up." : "We’ll notify you when recordings start, finish, or need attention."}
        />
      )}
      <p className="mt-4 text-xs text-muted-foreground">
        Choose which emails you receive in{" "}
        <Link to="/settings/notifications" className="text-primary underline underline-offset-4">
          notification settings
        </Link>
        .
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
              We’re confirming this payment with the SaveStream backend.
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
            body="The browser redirect is not proof of payment. Retry the backend status check before assuming credits were added."
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
              body={`Order ${order.id} is still ${order.status}. SaveStream will keep checking the backend; credits are not considered added until the order becomes paid.`}
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
            title={`${order.credits} credits added`}
            body="The SaveStream backend confirmed this payment as paid. Your credit balance and ledger are being refreshed from the server."
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
                ? `Order ${order.id} is ${paymentReturnStatusLabel(order.status)}. The credit ledger shown in Usage is the authoritative current balance.`
                : `Order ${order.id} is ${paymentReturnStatusLabel(order.status)}. No success is inferred from the checkout redirect.`
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
              No payment order was supplied. SaveStream only treats a purchase as complete when the
              backend confirms its payment status.
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
              Checking the backend payment status…
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
                ? `Order ${order.id} is paid according to the backend. Credits may already be reflected in your balance.`
                : isAwaitingPaymentConfirmation(order.status)
                  ? `Order ${order.id} is still ${order.status}. This page does not mark it canceled; refresh Billing later because webhook or reconciliation may still update it.`
                  : `Order ${order.id} is ${paymentReturnStatusLabel(order.status)} according to the backend.`
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
export function AdminWorkersPage() {
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
export function AdminJobsPage() {
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
export function AdminErrorsPage() {
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

/* ---------------- Public: legal, status ---------------- */
type LegalSection = { h: string; p: ReactNode };
export function LegalPage({
  title,
  intro,
  sections,
}: {
  title: string;
  intro: string;
  sections: LegalSection[];
}) {
  const { t } = usePreferences();
  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <main className="mx-auto max-w-3xl px-4 pb-20 pt-28 sm:px-6">
        <p className="text-xs text-muted-foreground">Last updated September 27, 2026</p>
        <h1 className="mt-2 text-3xl font-semibold">{title}</h1>
        <p className="mt-3 text-muted-foreground">{intro}</p>
        <div className="mt-6">
          <StateBanner
            tone="warning"
            title="Draft — for legal review before launch"
            body="This is placeholder copy for the prototype. It must be reviewed and completed by qualified counsel before SaveStream launches."
          />
        </div>
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
  return (
    <LegalPage
      title="Terms of Service"
      intro="These terms describe how you may use SaveStream, a cloud service that monitors TikTok channels and records their livestreams."
      sections={[
        {
          h: "The service",
          p: (
            <p>
              SaveStream checks the live status of channels you add and records livestreams on our
              servers. Recordings are stored for the retention period of your plan and can be
              watched or downloaded during that time.
            </p>
          ),
        },
        {
          h: "Authorized recording only",
          p: (
            <p>
              {authorized} You must stop monitoring a channel as soon as your permission ends. See
              the{" "}
              <Link to="/acceptable-use" className="text-primary underline underline-offset-4">
                Acceptable Use Policy
              </Link>
              .
            </p>
          ),
        },
        {
          h: "Your responsibility for content",
          p: (
            <p>
              You are solely responsible for confirming you have the rights and authorization to
              record, store, and use each livestream, and for how you use recordings afterward.
              SaveStream does not verify ownership of channels.
            </p>
          ),
        },
        {
          h: "Retention and deletion",
          p: (
            <p>
              Recordings expire and are deleted automatically at the end of your plan’s retention
              period (currently 3 days on Free and 30 days on Pro). Deleted recordings cannot be
              recovered. Download any recording you want to keep.
            </p>
          ),
        },
        {
          h: "Plans, quotas, and billing",
          p: (
            <p>
              Plans include limits on recording hours, monitored channels, simultaneous recordings,
              and downloads. When a limit is reached, automatic recording or downloads may pause
              until the next billing period. Paid plans renew automatically until canceled. [Refund
              terms — to be completed by legal.]
            </p>
          ),
        },
        {
          h: "Availability",
          p: (
            <p>
              Recording depends on third-party platforms. We can’t guarantee every livestream will
              be detected or fully recorded. [Service level and liability terms — to be completed by
              legal.]
            </p>
          ),
        },
        {
          h: "Termination",
          p: (
            <p>
              We may suspend accounts that record content without authorization or violate these
              terms. You can delete your account at any time from Settings.
            </p>
          ),
        },
        { h: "Contact", p: <p>[Company legal name, address, and contact email — placeholder.]</p> },
      ]}
    />
  );
}
export function PrivacyPage() {
  return (
    <LegalPage
      title="Privacy Policy"
      intro="This policy explains what information SaveStream handles and why. Sections marked as placeholders must be completed before launch."
      sections={[
        {
          h: "Information we collect",
          p: (
            <p>
              Account details (name, email, password hash or sign-in provider), channels you add,
              recordings and their metadata, usage statistics, and billing records handled by our
              payment provider. [Full data inventory — placeholder.]
            </p>
          ),
        },
        {
          h: "How we use it",
          p: (
            <p>
              To operate monitoring and recording, send notifications you’ve enabled, enforce plan
              limits, process payments, prevent abuse, and provide support.
            </p>
          ),
        },
        {
          h: "Recordings",
          p: (
            <p>
              Recordings are stored in cloud storage associated with your account and are only
              accessible to you and to authorized staff when needed for support or abuse
              investigations. {authorized}
            </p>
          ),
        },
        {
          h: "Retention",
          p: (
            <p>
              Recordings are deleted automatically when your plan’s retention period ends, or sooner
              if you delete them. Account data is deleted when you delete your account, except where
              we must keep records by law. [Exact retention schedule — placeholder.]
            </p>
          ),
        },
        {
          h: "Your choices",
          p: (
            <p>
              You can update your profile, change notification emails, export your account data, and
              delete your account from Settings. [Regional rights (e.g. access, correction, deletion
              requests) — to be completed by legal.]
            </p>
          ),
        },
        {
          h: "Service providers",
          p: <p>[List of hosting, storage, email, and payment processors — placeholder.]</p>,
        },
        { h: "Contact", p: <p>[Privacy contact email — placeholder.]</p> },
      ]}
    />
  );
}
export function AcceptableUsePage() {
  return (
    <LegalPage
      title="Acceptable Use Policy"
      intro="SaveStream is built for creators, brands, and teams archiving livestreams they are authorized to record."
      sections={[
        {
          h: "Allowed",
          p: (
            <ul className="list-disc space-y-1 pl-5">
              <li>Recording your own TikTok channel’s livestreams.</li>
              <li>Recording channels you manage on behalf of a creator or business.</li>
              <li>
                Recording channels whose owner has given you permission to record and archive.
              </li>
            </ul>
          ),
        },
        {
          h: "Not allowed",
          p: (
            <ul className="list-disc space-y-1 pl-5">
              <li>Recording channels without the owner’s permission.</li>
              <li>
                Redistributing recordings in violation of the creator’s rights or platform terms.
              </li>
              <li>Using SaveStream to harass, surveil, or collect data about individuals.</li>
              <li>Attempting to bypass plan limits or overload the service.</li>
            </ul>
          ),
        },
        {
          h: "Your responsibility",
          p: (
            <p>
              You are responsible for ensuring you own, manage, or have permission to record each
              channel’s livestreams.
            </p>
          ),
        },
        {
          h: "Enforcement",
          p: (
            <p>
              We may pause monitoring, remove recordings, or suspend accounts that violate this
              policy. [Appeals process — placeholder.]
            </p>
          ),
        },
        {
          h: "Reporting",
          p: (
            <p>
              If you believe a channel is being recorded without authorization, contact [abuse
              contact — placeholder].
            </p>
          ),
        },
      ]}
    />
  );
}
export function StatusPage() {
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
const helpTopics: { id: string; icon: typeof Cloud; title: string; body: string }[] = [
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

export function HelpPage() {
  const { t } = usePreferences();
  const [contact, setContact] = useState(false);
  const [msg, setMsg] = useState("");
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
          <p className="text-sm text-muted-foreground">{t("This demo does not send support messages.")}</p>
        </div>
        <Button onClick={() => setContact(true)}>{t("Contact support")}</Button>
      </section>
      <p className="mt-4 text-xs text-muted-foreground">
        <Link to="/status" className="text-primary underline underline-offset-4">
          {t("Service issues? Check the status page.")}
        </Link>
      </p>
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
                toast.success(t("Demo function"), { description: t("This demo does not send support messages.") });
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