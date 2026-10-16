import type { ReactNode } from "react";
import { Link } from "@tanstack/react-router";

import { Logo } from "@/components/app-components";
import { usePublicPricingData } from "@/hooks/use-domain-data";
import type { PublicPricingResponse } from "@/api/types";
import { pluralize } from "@/lib/formatters";
import { cn } from "@/lib/utils";

/**
 * Shared pieces of the auth screens (design "SignIn / SignUp / ForgotPassword
 * / ResetPassword / VerifyEmail / VerifySuccess / AuthError").
 */

/** Verification and reset links are valid for 30 minutes (backend
 * `SAVESTREAM_ONE_TIME_TOKEN_TTL_SECONDS`, default 1800). */
export const ONE_TIME_LINK_MINUTES = 30;

/** Free trial length in recording minutes, from the live pricing rule. */
export function trialMinutes(pricing: PublicPricingResponse | null | undefined): number | null {
  const credits = pricing?.signup_credits ?? 0;
  const rate = pricing?.recording_rate;
  if (!credits || !rate?.credits_per_unit || !rate.unit_seconds) return null;
  return Math.floor((credits / rate.credits_per_unit) * (rate.unit_seconds / 60));
}

export function useTrialMinutesLabel(): string | null {
  const { query } = usePublicPricingData();
  const minutes = trialMinutes(query.data);
  return minutes ? `${pluralize(minutes, "free trial minute")}` : null;
}

export function GoogleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true">
      <path
        d="M21.6 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.4a4.6 4.6 0 0 1-2 3v2.5h3.2c1.9-1.7 3-4.3 3-7.3z"
        fill="#4285F4"
      />
      <path
        d="M12 22c2.7 0 5-.9 6.6-2.5l-3.2-2.5c-.9.6-2 1-3.4 1-2.6 0-4.8-1.8-5.6-4.1H3.1v2.6A10 10 0 0 0 12 22z"
        fill="#34A853"
      />
      <path d="M6.4 13.9a6 6 0 0 1 0-3.8V7.5H3.1a10 10 0 0 0 0 9z" fill="#FBBC05" />
      <path
        d="M12 6c1.5 0 2.8.5 3.8 1.5l2.9-2.9A10 10 0 0 0 3.1 7.5l3.3 2.6C7.2 7.8 9.4 6 12 6z"
        fill="#EA4335"
      />
    </svg>
  );
}

export function AppleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M16.4 12.6c0-2.4 2-3.5 2-3.6-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.8-3.5.8-.7 0-1.8-.8-3-.8-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7c1.3 0 2.1-1.1 2.8-2.3.9-1.3 1.3-2.6 1.3-2.6s-2.5-1-2.5-3.6zM14.1 5.6c.6-.8 1.1-1.9 1-3-.9 0-2.1.6-2.7 1.4-.6.7-1.1 1.8-1 2.9 1 .1 2.1-.5 2.7-1.3z" />
    </svg>
  );
}

/** Outlined social sign-in button (design `.btn-social`). */
export function SocialButton({
  provider,
  label,
  disabled,
  onClick,
  className,
}: {
  provider: "google" | "apple";
  label: string;
  disabled?: boolean | undefined;
  onClick: () => void;
  className?: string | undefined;
}) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className={cn(
        "inline-flex min-h-12 items-center justify-center gap-2.5 rounded-xl border border-line-strong bg-surface px-4 text-sm font-semibold transition hover:border-primary hover:bg-surface-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-60",
        className,
      )}
    >
      {provider === "google" ? <GoogleIcon /> : <AppleIcon />}
      {label}
    </button>
  );
}

export function OrDivider({ children = "or with email" }: { children?: ReactNode }) {
  return (
    <div className="flex items-center gap-3 text-xs text-muted-foreground">
      <span className="h-px flex-1 bg-border" />
      {children}
      <span className="h-px flex-1 bg-border" />
    </div>
  );
}

/** Rounded icon tile used on the card screens (design `.icotile`). */
export function IconTile({
  tone = "accent",
  size = "lg",
  children,
}: {
  tone?: "accent" | "ok" | "warn" | "err" | "muted";
  size?: "md" | "lg" | "xl";
  children: ReactNode;
}) {
  return (
    <span
      aria-hidden="true"
      className={cn(
        "grid shrink-0 place-items-center",
        size === "md" && "size-14 rounded-[18px]",
        size === "lg" && "size-16 rounded-[20px]",
        size === "xl" && "size-[72px] rounded-[22px]",
        tone === "accent" && "bg-primary-subtle text-accent-ink",
        tone === "ok" && "bg-success-subtle text-success",
        tone === "warn" && "bg-warning-subtle text-warning",
        tone === "err" && "bg-destructive/10 text-destructive",
        tone === "muted" && "bg-surface-2 text-muted-foreground",
      )}
    >
      {children}
    </span>
  );
}

function LegalFooter({ refund = false }: { refund?: boolean }) {
  return (
    <p className="text-xs text-muted-foreground">
      © 2026 SaveStream ·{" "}
      <Link to="/terms" className="hover:text-foreground">
        Terms of Use
      </Link>{" "}
      ·{" "}
      <Link to="/privacy" className="hover:text-foreground">
        Privacy Policy
      </Link>{" "}
      ·{" "}
      {refund ? (
        <Link to="/refund" className="hover:text-foreground">
          Refund Policy
        </Link>
      ) : (
        <Link to="/acceptable-use" className="hover:text-foreground">
          Acceptable Use
        </Link>
      )}
    </p>
  );
}

function SignInAside() {
  const { query } = usePublicPricingData();
  const retention = query.data?.recording_retention_days;
  const facts = [
    "No credit card to start",
    "Credits never expire",
    retention ? `Stored up to ${pluralize(retention, "day")}` : null,
  ].filter(Boolean);
  return (
    <aside className="relative m-4 hidden flex-col justify-between overflow-hidden rounded-[28px] bg-[radial-gradient(500px_280px_at_15%_0%,rgba(255,122,182,.45),transparent_70%),radial-gradient(600px_340px_at_100%_100%,rgba(80,200,255,.3),transparent_70%),linear-gradient(135deg,#4B2BD9,#6D4AFF_55%,#8E5BFF)] p-14 text-white lg:flex">
      <div className="flex max-w-[460px] flex-col gap-4">
        <span className="inline-flex h-7 items-center self-start rounded-full bg-white/15 px-3 text-xs font-semibold">
          Cloud recording for TikTok LIVE
        </span>
        <h2 className="text-[38px] font-extrabold leading-[1.1] tracking-[-0.03em]">
          Your LIVEs keep recording while you sleep.
        </h2>
      </div>
      {/* Illustration of a running recording, not live data. */}
      <div
        aria-hidden="true"
        className="flex max-w-[420px] flex-col gap-3 rounded-[18px] bg-white/95 p-[18px] text-[#15122B] shadow-[0_30px_60px_-20px_rgba(0,0,0,.45)]"
      >
        <div className="flex items-center gap-3">
          <span className="grid size-9 place-items-center rounded-full bg-gradient-to-br from-avatar-one to-avatar-one-end text-xs font-semibold text-avatar-foreground ring-2 ring-white">
            YC
          </span>
          <div className="flex flex-col">
            <b className="text-sm">@your.channel</b>
            <span className="text-xs text-[#56526F]">Went LIVE · recording in the cloud</span>
          </div>
          <span className="ml-auto inline-flex h-6 items-center gap-1.5 rounded-full bg-recording px-2.5 text-[11px] font-bold text-white">
            <span className="size-1.5 animate-pulse rounded-full bg-white" />
            LIVE
          </span>
        </div>
        <div className="flex items-center gap-2.5 rounded-xl bg-[#F4F1FF] px-3.5 py-2.5">
          <span className="size-2 animate-pulse rounded-full bg-recording" />
          <span className="text-xs font-semibold text-[#56526F]">Recording</span>
          <span className="ml-auto font-mono text-xl font-semibold">0:42:09</span>
        </div>
      </div>
      <div className="flex flex-wrap gap-x-[18px] gap-y-1 text-sm text-white/90">
        {facts.map((fact, index) => (
          <span key={fact} className="flex gap-[18px]">
            {index > 0 && <span aria-hidden="true">·</span>}
            {fact}
          </span>
        ))}
      </div>
    </aside>
  );
}

function SignUpAside() {
  const trial = useTrialMinutesLabel();
  const steps: [string, string][] = [
    ["Verify your email", "Open the link we send you"],
    ["Add your TikTok channel", "Just the @username"],
    [
      "Turn on Auto-record",
      trial
        ? `Your ${trial} arrive when you verify — try Auto-record on a real LIVE`
        : "Try Auto-record on a real LIVE with your free minutes",
    ],
  ];
  return (
    <aside className="m-4 hidden flex-col justify-center gap-7 rounded-[28px] border bg-gradient-to-br from-primary-subtle to-surface-2 p-14 lg:flex">
      <span className="text-xs font-bold uppercase tracking-[.08em] text-accent-ink">
        What happens next
      </span>
      <h2 className="max-w-[460px] text-[34px] font-extrabold leading-[1.12] tracking-[-0.03em]">
        You’re about 2 minutes from your first monitored channel.
      </h2>
      <ol className="flex max-w-[460px] flex-col gap-3.5">
        {steps.map(([title, body], index) => (
          <li key={title} className="flex items-center gap-3.5 rounded-2xl border bg-surface p-4">
            <span
              className={cn(
                "grid size-10 shrink-0 place-items-center rounded-xl font-bold",
                index === 0
                  ? "bg-primary text-primary-foreground"
                  : "bg-primary-subtle text-accent-ink",
              )}
            >
              {index + 1}
            </span>
            <div className="flex flex-col gap-1">
              <b className="text-sm">{title}</b>
              <span className="text-xs text-muted-foreground">{body}</span>
            </div>
          </li>
        ))}
      </ol>
    </aside>
  );
}

/** Split auth layout: form on the left, brand panel on the right. */
export function AuthSplitLayout({
  variant,
  topRight,
  children,
}: {
  variant: "sign-in" | "sign-up";
  topRight?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="grid min-h-screen bg-background lg:grid-cols-2">
      <main className="flex flex-col px-6 py-8 sm:px-10">
        <div className="flex items-center justify-between gap-4">
          <Logo />
          {topRight}
        </div>
        <div className="m-auto flex w-full max-w-[420px] flex-col gap-6 py-12">{children}</div>
        <LegalFooter refund={variant === "sign-up"} />
      </main>
      {variant === "sign-in" ? <SignInAside /> : <SignUpAside />}
    </div>
  );
}

/** Centered card on a soft glow (forgot/reset password, verify, errors). */
export function AuthCardLayout({
  topRight,
  footer,
  width = "md",
  children,
}: {
  topRight?: ReactNode;
  footer?: ReactNode;
  width?: "md" | "lg";
  children: ReactNode;
}) {
  return (
    <div className="relative flex min-h-screen flex-col overflow-hidden bg-background px-6 py-8 sm:px-10">
      <div aria-hidden className="hero-glow" />
      <div className="relative flex items-center justify-between gap-4">
        <Logo />
        {topRight}
      </div>
      <main
        className={cn(
          "relative m-auto flex w-full flex-col gap-[22px] rounded-3xl border bg-surface p-8 shadow-card sm:p-10",
          width === "md" ? "max-w-[460px]" : "max-w-[520px]",
        )}
      >
        {children}
      </main>
      <div className="relative text-center text-xs text-muted-foreground">
        {footer ?? (
          <>
            Need help?{" "}
            <Link to="/contact" className="text-accent-ink hover:underline">
              Contact support
            </Link>{" "}
            ·{" "}
            <Link to="/status" className="text-accent-ink hover:underline">
              System status
            </Link>
          </>
        )}
      </div>
    </div>
  );
}

/** Password rules checklist shown under the sign-up / reset password field. */
export function PasswordChecklist({ value }: { value: string }) {
  const rules: [boolean, string, boolean][] = [
    [value.length >= 8, "8+ characters", true],
    [/\d/.test(value), "A number", false],
    [/[A-Z]/.test(value) && /[a-z]/.test(value), "Upper & lower case", false],
    [/[^A-Za-z0-9]/.test(value), "A symbol (optional)", false],
  ];
  const met = rules.filter(([ok]) => ok).length;
  return (
    <div className="flex flex-col gap-2">
      <div className="flex gap-1.5" aria-hidden="true">
        {[0, 1, 2, 3].map((index) => (
          <span
            key={index}
            className={cn(
              "h-1.5 flex-1 rounded-full bg-surface-2",
              index < met &&
                (met <= 1 ? "bg-destructive" : met === 2 ? "bg-warning" : "bg-success"),
            )}
          />
        ))}
      </div>
      <ul className="grid grid-cols-2 gap-x-3 gap-y-1">
        {rules.map(([ok, label, required]) => (
          <li
            key={label}
            className={cn("text-xs", ok ? "text-success" : "text-muted-foreground")}
            aria-label={`${label}: ${ok ? "met" : required ? "required" : "recommended"}`}
          >
            {ok ? "✓" : "○"} {label}
          </li>
        ))}
      </ul>
    </div>
  );
}
