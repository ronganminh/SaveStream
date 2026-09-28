import { Link, useNavigate } from "@tanstack/react-router";
import { ArrowLeft, ArrowRight, Check, CircleAlert, Eye, EyeOff, LoaderCircle } from "lucide-react";
import { useMemo, useState, type FormEvent, type ReactNode } from "react";
import { Logo, SaveStreamMark } from "./components/brand";
import { PreferencesControls } from "./components/preferences-controls";
import { usePreferences } from "./lib/preferences";

const primaryButton =
  "inline-flex h-11 items-center justify-center gap-2 rounded-lg bg-indigo-600 px-4 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-400 disabled:cursor-not-allowed disabled:opacity-60";
const socialButton =
  "inline-flex h-11 w-full items-center justify-center gap-3 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-4 text-sm font-semibold transition hover:bg-[var(--subtle)] focus:outline-none focus:ring-2 focus:ring-indigo-400 disabled:cursor-not-allowed disabled:opacity-60";

type AuthMode = "sign-in" | "sign-up" | "forgot" | "reset";
type SocialProvider = "google" | "apple" | "github";

export function AuthPage({ mode }: { mode: AuthMode }) {
  const navigate = useNavigate();
  const { t } = usePreferences();
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(true);
  const [loading, setLoading] = useState(false);
  const [socialLoading, setSocialLoading] = useState<SocialProvider | null>(null);
  const [error, setError] = useState("");

  const title = {
    "sign-in": t("auth.welcomeBack"),
    "sign-up": t("auth.createAccountTitle"),
    forgot: t("auth.resetTitle"),
    reset: t("auth.newPasswordTitle"),
  }[mode];
  const showSocial = mode === "sign-in" || mode === "sign-up";
  const showPasswordRules = mode === "sign-up" || mode === "reset";

  const passwordRules = useMemo(
    () => [
      { label: t("auth.ruleLength"), valid: password.length >= 8 },
      { label: t("auth.ruleNumber"), valid: /\d/.test(password) },
      { label: t("auth.ruleUppercase"), valid: /[A-Z]/.test(password) },
    ],
    [password, t],
  );
  const passwordScore = passwordRules.filter((rule) => rule.valid).length;
  const strengthLabel = passwordScore <= 1 ? t("auth.strengthWeak") : passwordScore === 2 ? t("auth.strengthGood") : t("auth.strengthStrong");

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");

    if ((mode === "sign-up" && !fullName.trim()) || (mode !== "reset" && !email.trim()) || (mode !== "forgot" && !password)) {
      setError(t("auth.required"));
      return;
    }
    if (mode !== "reset" && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setError(t("auth.invalidEmail"));
      return;
    }
    if (mode !== "forgot" && password.length < 8) {
      setError(t("auth.passwordShort"));
      return;
    }

    setLoading(true);
    await wait(700);
    setLoading(false);

    if (mode === "sign-up") {
      await navigate({ to: "/verify-email" });
    } else if (mode === "sign-in") {
      await navigate({ to: "/overview" });
    } else {
      await navigate({ to: "/sign-in" });
    }
  }

  async function handleSocial(provider: SocialProvider) {
    setError("");
    setSocialLoading(provider);
    await wait(650);
    setSocialLoading(null);
    await navigate({ to: mode === "sign-up" ? "/onboarding" : "/overview" });
  }

  const submitLabel = loading
    ? mode === "sign-up"
      ? t("auth.creating")
      : mode === "forgot"
        ? t("auth.sending")
        : mode === "reset"
          ? t("auth.resetting")
          : t("auth.signingIn")
    : mode === "sign-up"
      ? t("auth.createAccount")
      : mode === "forgot"
        ? t("auth.sendReset")
        : mode === "reset"
          ? t("auth.resetPassword")
          : t("nav.signIn");

  return (
    <div className="grid min-h-screen bg-[var(--bg)] text-[var(--fg)] lg:grid-cols-[minmax(0,1.05fr)_minmax(460px,.95fr)]">
      <div className="flex min-h-screen flex-col p-5 sm:p-8 lg:p-10 xl:p-12">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <Logo />
          <div className="flex items-center gap-3">
            <PreferencesControls compact />
            {mode === "sign-in" && (
              <p className="hidden text-sm text-[var(--muted)] xl:block">
                {t("auth.newUser")} <Link to="/sign-up" className="font-semibold text-indigo-600 hover:text-indigo-500">{t("nav.signUp")}</Link>
              </p>
            )}
            {mode === "sign-up" && (
              <p className="hidden text-sm text-[var(--muted)] xl:block">
                {t("auth.haveAccount")} <Link to="/sign-in" className="font-semibold text-indigo-600 hover:text-indigo-500">{t("nav.signIn")}</Link>
              </p>
            )}
          </div>
        </div>

        <div className="my-auto w-full max-w-md self-center py-10 sm:py-14">
          <Link to="/" className="mb-7 inline-flex items-center gap-2 text-sm font-medium text-[var(--muted)] transition hover:text-[var(--fg)]">
            <ArrowLeft className="size-4" /> {t("auth.backHome")}
          </Link>
          <h1 className="text-3xl font-semibold tracking-tight">{title}</h1>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
            {mode === "sign-up" ? t("auth.signUpBody") : mode === "sign-in" ? t("auth.signInBody") : t("auth.recoveryBody")}
          </p>

          {showSocial && (
            <>
              <div className="mt-8 grid gap-3">
                <SocialButton provider="google" loading={socialLoading === "google"} disabled={Boolean(socialLoading) || loading} onClick={() => handleSocial("google")} label={t("auth.continueGoogle")} icon={<GoogleIcon />} />
                <SocialButton provider="apple" loading={socialLoading === "apple"} disabled={Boolean(socialLoading) || loading} onClick={() => handleSocial("apple")} label={t("auth.continueApple")} icon={<AppleIcon />} />
                <SocialButton provider="github" loading={socialLoading === "github"} disabled={Boolean(socialLoading) || loading} onClick={() => handleSocial("github")} label={t("auth.continueGitHub")} icon={<GitHubIcon />} />
              </div>

              <div className="my-7 flex items-center gap-3">
                <span className="h-px flex-1 bg-[var(--border)]" />
                <span className="text-center text-[10px] font-medium uppercase tracking-[.16em] text-[var(--muted)] sm:text-xs">{t("auth.continueEmail")}</span>
                <span className="h-px flex-1 bg-[var(--border)]" />
              </div>
            </>
          )}

          <form onSubmit={handleSubmit} className={`${showSocial ? "" : "mt-8"} space-y-4`} noValidate>
            {mode === "sign-up" && (
              <Field label={t("auth.fullName")} placeholder="Alex Nguyen" autoComplete="name" value={fullName} onChange={setFullName} />
            )}
            {mode !== "reset" && (
              <Field label={t("auth.email")} placeholder="you@company.com" type="email" autoComplete="email" value={email} onChange={setEmail} />
            )}
            {mode !== "forgot" && (
              <PasswordField
                label={mode === "reset" ? t("auth.newPassword") : t("auth.password")}
                value={password}
                onChange={setPassword}
                autoComplete={mode === "sign-in" ? "current-password" : "new-password"}
              />
            )}

            {showPasswordRules && password.length > 0 && (
              <div className="rounded-lg border border-[var(--border)] bg-[var(--subtle)] p-3">
                <div className="flex items-center justify-between text-xs">
                  <span className="font-medium">{t("auth.passwordStrength")}</span>
                  <span className={passwordScore === 3 ? "text-emerald-600" : passwordScore === 2 ? "text-amber-600" : "text-red-600"}>{strengthLabel}</span>
                </div>
                <div className="mt-2 grid grid-cols-3 gap-1">
                  {[0, 1, 2].map((index) => <span key={index} className={`h-1 rounded-full ${index < passwordScore ? (passwordScore === 3 ? "bg-emerald-500" : passwordScore === 2 ? "bg-amber-500" : "bg-red-500") : "bg-[var(--border)]"}`} />)}
                </div>
                <ul className="mt-3 space-y-1.5 text-xs text-[var(--muted)]">
                  {passwordRules.map((rule) => (
                    <li key={rule.label} className="flex items-center gap-2">
                      <Check className={`size-3.5 ${rule.valid ? "text-emerald-600" : "text-[var(--muted)]"}`} /> {rule.label}
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {mode === "sign-in" && (
              <div className="flex items-center justify-between gap-4">
                <label className="inline-flex items-center gap-2 text-sm text-[var(--muted)]">
                  <input type="checkbox" checked={remember} onChange={(event) => setRemember(event.target.checked)} className="size-4 rounded border-[var(--border)] accent-indigo-600" />
                  {t("auth.remember")}
                </label>
                <Link to="/forgot-password" className="text-sm font-medium text-indigo-600 hover:text-indigo-500">{t("auth.forgot")}</Link>
              </div>
            )}

            {error && (
              <div role="alert" aria-live="polite" className="flex items-start gap-2 rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-700 dark:border-red-500/25 dark:bg-red-500/10 dark:text-red-300">
                <CircleAlert className="mt-0.5 size-4 shrink-0" /> {error}
              </div>
            )}

            <button type="submit" className={`${primaryButton} w-full`} disabled={loading || Boolean(socialLoading)}>
              {loading && <LoaderCircle className="size-4 animate-spin" />}
              {submitLabel}
              {!loading && <ArrowRight className="size-4" />}
            </button>
          </form>

          {mode === "sign-up" && (
            <p className="mt-5 text-xs leading-5 text-[var(--muted)]">
              {t("auth.termsPrefix")} <Link to="/terms" className="underline underline-offset-2">{t("auth.terms")}</Link> {t("auth.and")} <Link to="/privacy" className="underline underline-offset-2">{t("auth.privacy")}</Link>.
            </p>
          )}

          <div className="mt-7 text-center text-sm text-[var(--muted)] xl:hidden">
            {mode === "sign-in" && <>{t("auth.newUser")} <Link to="/sign-up" className="font-semibold text-indigo-600">{t("nav.signUp")}</Link></>}
            {mode === "sign-up" && <>{t("auth.haveAccount")} <Link to="/sign-in" className="font-semibold text-indigo-600">{t("nav.signIn")}</Link></>}
          </div>
        </div>
      </div>

      <div className="hidden place-items-center overflow-hidden border-l border-[var(--border)] bg-gradient-to-br from-indigo-50 via-white to-violet-100 lg:grid dark:from-indigo-950/30 dark:via-[var(--surface)] dark:to-violet-950/30">
        <div className="max-w-xl px-12 xl:px-16">
          <SaveStreamMark className="size-16" />
          <p className="mt-9 text-4xl font-medium leading-tight tracking-tight">{t("auth.hero")}</p>
          <div className="mt-10 rounded-2xl border border-red-200 bg-white/70 p-5 shadow-xl shadow-indigo-950/5 backdrop-blur dark:border-red-500/20 dark:bg-black/10">
            <p className="text-xs font-semibold uppercase tracking-wide text-red-600">● {t("auth.recordingNow")}</p>
            <div className="mt-4 flex items-end justify-between gap-5">
              <div>
                <p className="font-semibold">@linastudio</p>
                <p className="mt-1 text-sm text-[var(--muted)]">{t("auth.recordingContinues")}</p>
              </div>
              <p className="font-mono text-2xl font-semibold">01:42:18</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function SocialButton({ label, icon, loading, disabled, onClick, provider }: { label: string; icon: ReactNode; loading: boolean; disabled: boolean; onClick: () => void; provider: SocialProvider }) {
  return (
    <button type="button" className={socialButton} onClick={onClick} disabled={disabled} aria-label={label} data-provider={provider}>
      {loading ? <LoaderCircle className="size-5 animate-spin" /> : icon}
      {label}
    </button>
  );
}

function Field({ label, placeholder, type = "text", autoComplete, value, onChange }: { label: string; placeholder: string; type?: string; autoComplete?: string; value: string; onChange: (value: string) => void }) {
  return (
    <label className="block text-sm font-medium">
      {label}
      <input type={type} placeholder={placeholder} autoComplete={autoComplete} value={value} onChange={(event) => onChange(event.target.value)} className="mt-2 h-11 w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 outline-none transition focus:border-indigo-400 focus:ring-2 focus:ring-indigo-400/30" />
    </label>
  );
}

function PasswordField({ label, value, onChange, autoComplete }: { label: string; value: string; onChange: (value: string) => void; autoComplete: string }) {
  const [visible, setVisible] = useState(false);
  const { t } = usePreferences();
  return (
    <label className="block text-sm font-medium">
      {label}
      <span className="relative mt-2 block">
        <input type={visible ? "text" : "password"} placeholder="••••••••" autoComplete={autoComplete} value={value} onChange={(event) => onChange(event.target.value)} className="h-11 w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 pr-11 outline-none transition focus:border-indigo-400 focus:ring-2 focus:ring-indigo-400/30" />
        <button type="button" onClick={() => setVisible((current) => !current)} className="absolute inset-y-0 right-0 grid w-11 place-items-center text-[var(--muted)] hover:text-[var(--fg)]" aria-label={visible ? t("auth.hidePassword") : t("auth.showPassword")}>
          {visible ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
        </button>
      </span>
    </label>
  );
}

function wait(duration: number) {
  return new Promise((resolve) => window.setTimeout(resolve, duration));
}

function GoogleIcon() {
  return (
    <svg viewBox="0 0 24 24" className="size-5" aria-hidden="true">
      <path fill="#4285F4" d="M21.6 12.23c0-.71-.06-1.39-.18-2.05H12v3.88h5.38a4.6 4.6 0 0 1-2 3.02v2.52h3.24c1.9-1.75 2.98-4.33 2.98-7.37Z" />
      <path fill="#34A853" d="M12 22c2.7 0 4.97-.9 6.62-2.4l-3.24-2.52c-.9.6-2.05.96-3.38.96-2.6 0-4.8-1.76-5.6-4.12H3.06v2.6A10 10 0 0 0 12 22Z" />
      <path fill="#FBBC05" d="M6.4 13.92a6 6 0 0 1 0-3.84v-2.6H3.06a10 10 0 0 0 0 9.04l3.34-2.6Z" />
      <path fill="#EA4335" d="M12 5.96c1.47 0 2.78.5 3.82 1.49l2.86-2.87A9.62 9.62 0 0 0 12 2a10 10 0 0 0-8.94 5.48l3.34 2.6c.8-2.36 3-4.12 5.6-4.12Z" />
    </svg>
  );
}

function AppleIcon() {
  return <svg viewBox="0 0 24 24" className="size-5 fill-current" aria-hidden="true"><path d="M16.7 12.9c0-2.3 1.9-3.4 2-3.5a4.4 4.4 0 0 0-3.5-1.9c-1.5-.2-2.9.9-3.7.9-.8 0-2-.9-3.3-.9a4.9 4.9 0 0 0-4.2 2.5c-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.2 2.5 1.3-.1 1.8-.8 3.4-.8 1.6 0 2 .8 3.4.8 1.4 0 2.3-1.2 3.1-2.5 1-1.4 1.4-2.8 1.4-2.9-.1 0-3.1-1.2-3.1-4.4ZM14.2 5.9c.7-.9 1.2-2.1 1.1-3.3-1.1 0-2.4.7-3.2 1.6-.7.8-1.3 2-1.1 3.2 1.2.1 2.4-.6 3.2-1.5Z" /></svg>;
}

function GitHubIcon() {
  return <svg viewBox="0 0 24 24" className="size-5 fill-current" aria-hidden="true"><path fillRule="evenodd" d="M12 2a10 10 0 0 0-3.16 19.49c.5.09.68-.22.68-.48l-.01-1.88c-2.78.6-3.37-1.18-3.37-1.18-.45-1.16-1.11-1.47-1.11-1.47-.9-.62.07-.61.07-.61 1 .07 1.52 1.03 1.52 1.03.89 1.52 2.33 1.08 2.9.83.09-.65.35-1.08.63-1.33-2.22-.25-4.56-1.11-4.56-4.94 0-1.09.39-1.98 1.03-2.68-.1-.25-.45-1.27.1-2.64 0 0 .84-.27 2.75 1.02A9.6 9.6 0 0 1 12 6.82a9.6 9.6 0 0 1 2.5.34c1.91-1.29 2.75-1.02 2.75-1.02.55 1.37.2 2.39.1 2.64.64.7 1.03 1.59 1.03 2.68 0 3.84-2.34 4.68-4.57 4.93.36.31.68.92.68 1.86l-.01 2.76c0 .27.18.58.69.48A10 10 0 0 0 12 2Z" clipRule="evenodd" /></svg>;
}
