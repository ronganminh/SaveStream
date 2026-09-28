import { Link } from "@tanstack/react-router";
import { ArrowRight } from "lucide-react";
import { Logo, SaveStreamMark } from "./components/brand";

const primaryButton =
  "inline-flex h-11 items-center justify-center gap-2 rounded-lg bg-indigo-600 px-4 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-400";
const socialButton =
  "inline-flex h-11 w-full items-center justify-center gap-3 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-4 text-sm font-semibold transition hover:bg-[var(--subtle)] focus:outline-none focus:ring-2 focus:ring-indigo-400";

type AuthMode = "sign-in" | "sign-up" | "forgot" | "reset";

export function AuthPage({ mode }: { mode: AuthMode }) {
  const title = {
    "sign-in": "Welcome back",
    "sign-up": "Create your account",
    forgot: "Reset your password",
    reset: "Choose a new password",
  }[mode];
  const socialDestination = mode === "sign-up" ? "/onboarding" : "/overview";
  const showSocial = mode === "sign-in" || mode === "sign-up";

  return (
    <div className="grid min-h-screen bg-[var(--bg)] text-[var(--fg)] lg:grid-cols-[minmax(0,1.05fr)_minmax(460px,.95fr)]">
      <div className="flex min-h-screen flex-col p-5 sm:p-8 lg:p-10 xl:p-12">
        <div className="flex items-center justify-between">
          <Logo />
          {mode === "sign-in" && (
            <p className="hidden text-sm text-[var(--muted)] sm:block">
              New to SaveStream?{" "}
              <Link to="/sign-up" className="font-semibold text-indigo-600 hover:text-indigo-500">
                Sign up
              </Link>
            </p>
          )}
          {mode === "sign-up" && (
            <p className="hidden text-sm text-[var(--muted)] sm:block">
              Already have an account?{" "}
              <Link to="/sign-in" className="font-semibold text-indigo-600 hover:text-indigo-500">
                Sign in
              </Link>
            </p>
          )}
        </div>

        <div className="my-auto w-full max-w-md self-center py-10 sm:py-14">
          <h1 className="text-3xl font-semibold tracking-tight">{title}</h1>
          <p className="mt-2 text-sm leading-6 text-[var(--muted)]">
            {mode === "sign-up"
              ? "Create an account and start monitoring your first TikTok channel."
              : mode === "sign-in"
                ? "Sign in to continue to your SaveStream workspace."
                : "We'll help you recover access to your account."}
          </p>

          {showSocial && (
            <>
              <div className="mt-8 grid gap-3">
                <Link to={socialDestination} className={socialButton} aria-label="Continue with Google">
                  <GoogleIcon />
                  Continue with Google
                </Link>
                <Link to={socialDestination} className={socialButton} aria-label="Continue with Apple">
                  <AppleIcon />
                  Continue with Apple
                </Link>
                <Link to={socialDestination} className={socialButton} aria-label="Continue with GitHub">
                  <GitHubIcon />
                  Continue with GitHub
                </Link>
              </div>

              <div className="my-7 flex items-center gap-3">
                <span className="h-px flex-1 bg-[var(--border)]" />
                <span className="text-xs font-medium uppercase tracking-[.18em] text-[var(--muted)]">or continue with email</span>
                <span className="h-px flex-1 bg-[var(--border)]" />
              </div>
            </>
          )}

          <form className={`${showSocial ? "" : "mt-8"} space-y-4`}>
            {mode === "sign-up" && <Field label="Full name" placeholder="Alex Nguyen" autoComplete="name" />}
            <Field label="Email" placeholder="you@company.com" type="email" autoComplete="email" />
            {mode !== "forgot" && (
              <Field
                label={mode === "reset" ? "New password" : "Password"}
                placeholder="••••••••"
                type="password"
                autoComplete={mode === "sign-in" ? "current-password" : "new-password"}
              />
            )}

            {mode === "sign-in" && (
              <div className="flex justify-end">
                <Link to="/forgot-password" className="text-sm font-medium text-indigo-600 hover:text-indigo-500">
                  Forgot password?
                </Link>
              </div>
            )}

            <Link
              to={mode === "sign-up" ? "/verify-email" : mode === "sign-in" ? "/overview" : "/sign-in"}
              className={`${primaryButton} w-full`}
            >
              {mode === "sign-up"
                ? "Create account"
                : mode === "forgot"
                  ? "Send reset link"
                  : mode === "reset"
                    ? "Reset password"
                    : "Sign in"}
              <ArrowRight className="size-4" />
            </Link>
          </form>

          {mode === "sign-up" && (
            <p className="mt-5 text-xs leading-5 text-[var(--muted)]">
              By creating an account, you agree to the{" "}
              <Link to="/terms" className="underline underline-offset-2">Terms of Service</Link>
              {" "}and{" "}
              <Link to="/privacy" className="underline underline-offset-2">Privacy Policy</Link>.
            </p>
          )}

          <div className="mt-7 text-center text-sm text-[var(--muted)] sm:hidden">
            {mode === "sign-in" && (
              <>New to SaveStream? <Link to="/sign-up" className="font-semibold text-indigo-600">Sign up</Link></>
            )}
            {mode === "sign-up" && (
              <>Already have an account? <Link to="/sign-in" className="font-semibold text-indigo-600">Sign in</Link></>
            )}
          </div>
        </div>
      </div>

      <div className="hidden place-items-center overflow-hidden border-l border-[var(--border)] bg-gradient-to-br from-indigo-50 via-white to-violet-100 lg:grid dark:from-indigo-950/30 dark:via-[var(--surface)] dark:to-violet-950/30">
        <div className="max-w-xl px-12 xl:px-16">
          <SaveStreamMark className="size-16" />
          <p className="mt-9 text-4xl font-medium leading-tight tracking-tight">
            We monitor. We record. You can close the browser.
          </p>
          <div className="mt-10 rounded-2xl border border-red-200 bg-white/70 p-5 shadow-xl shadow-indigo-950/5 backdrop-blur dark:border-red-500/20 dark:bg-black/10">
            <p className="text-xs font-semibold uppercase tracking-wide text-red-600">● Recording now</p>
            <div className="mt-4 flex items-end justify-between gap-5">
              <div>
                <p className="font-semibold">@linastudio</p>
                <p className="mt-1 text-sm text-[var(--muted)]">Recording continues on our servers.</p>
              </div>
              <p className="font-mono text-2xl font-semibold">01:42:18</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function Field({
  label,
  placeholder,
  type = "text",
  autoComplete,
}: {
  label: string;
  placeholder: string;
  type?: string;
  autoComplete?: string;
}) {
  return (
    <label className="block text-sm font-medium">
      {label}
      <input
        type={type}
        placeholder={placeholder}
        autoComplete={autoComplete}
        className="mt-2 h-11 w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 outline-none transition focus:border-indigo-400 focus:ring-2 focus:ring-indigo-400/30"
      />
    </label>
  );
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
  return (
    <svg viewBox="0 0 24 24" className="size-5 fill-current" aria-hidden="true">
      <path d="M16.7 12.9c0-2.3 1.9-3.4 2-3.5a4.4 4.4 0 0 0-3.5-1.9c-1.5-.2-2.9.9-3.7.9-.8 0-2-.9-3.3-.9a4.9 4.9 0 0 0-4.2 2.5c-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.2 2.5 1.3-.1 1.8-.8 3.4-.8 1.6 0 2 .8 3.4.8 1.4 0 2.3-1.2 3.1-2.5 1-1.4 1.4-2.8 1.4-2.9-.1 0-3.1-1.2-3.1-4.4ZM14.2 5.9c.7-.9 1.2-2.1 1.1-3.3-1.1 0-2.4.7-3.2 1.6-.7.8-1.3 2-1.1 3.2 1.2.1 2.4-.6 3.2-1.5Z" />
    </svg>
  );
}

function GitHubIcon() {
  return (
    <svg viewBox="0 0 24 24" className="size-5 fill-current" aria-hidden="true">
      <path fillRule="evenodd" d="M12 2a10 10 0 0 0-3.16 19.49c.5.09.68-.22.68-.48l-.01-1.88c-2.78.6-3.37-1.18-3.37-1.18-.45-1.16-1.11-1.47-1.11-1.47-.9-.62.07-.61.07-.61 1 .07 1.52 1.03 1.52 1.03.89 1.52 2.33 1.08 2.9.83.09-.65.35-1.08.63-1.33-2.22-.25-4.56-1.11-4.56-4.94 0-1.09.39-1.98 1.03-2.68-.1-.25-.45-1.27.1-2.64 0 0 .84-.27 2.75 1.02A9.6 9.6 0 0 1 12 6.82a9.6 9.6 0 0 1 2.5.34c1.91-1.29 2.75-1.02 2.75-1.02.55 1.37.2 2.39.1 2.64.64.7 1.03 1.59 1.03 2.68 0 3.84-2.34 4.68-4.57 4.93.36.31.68.92.68 1.86l-.01 2.76c0 .27.18.58.69.48A10 10 0 0 0 12 2Z" clipRule="evenodd" />
    </svg>
  );
}
