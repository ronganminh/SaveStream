import { Link } from "@tanstack/react-router";
import {
  ArrowRight,
  Check,
  Cloud,
  Play,
  Plus,
  Radio,
  Video,
} from "lucide-react";
import { Logo, SaveStreamMark } from "./components/brand";
import { StatusBadge } from "./components/ui";
import { recordings } from "./lib/mock-data";

const primaryButton =
  "inline-flex h-10 items-center justify-center gap-2 rounded-lg bg-indigo-600 px-4 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-400";
const secondaryButton =
  "inline-flex h-10 items-center justify-center gap-2 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-4 text-sm font-semibold transition hover:bg-[var(--subtle)]";

export function LandingPage() {
  return (
    <div className="min-h-screen bg-[var(--bg)] text-[var(--fg)]">
      <header className="sticky top-0 z-30 border-b border-[var(--border)] bg-[color:var(--bg)]/90 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-[1540px] items-center px-4 sm:px-6 lg:px-8">
          <Logo />
          <nav className="ml-10 hidden items-center gap-7 text-sm text-[var(--muted)] md:flex">
            <a href="#features">Features</a>
            <a href="#how">How it works</a>
            <a href="#examples">Examples</a>
            <Link to="/pricing">Pricing</Link>
          </nav>
          <div className="ml-auto flex items-center gap-2">
            <Link
              to="/sign-in"
              className="hidden h-10 items-center px-3 text-sm font-medium sm:inline-flex"
            >
              Sign in
            </Link>
            <Link to="/sign-up" className={primaryButton}>
              Sign up
            </Link>
          </div>
        </div>
      </header>

      <main>
        <section className="border-b border-[var(--border)] px-4 pb-16 pt-16 text-center sm:pb-20 sm:pt-20 lg:px-8 lg:pb-24 lg:pt-24">
          <span className="inline-flex items-center gap-2 rounded-full border border-[var(--border)] bg-[var(--surface)] px-3 py-1 text-xs text-[var(--muted)]">
            <Cloud className="size-3 text-indigo-600" />
            Automatic cloud recording
          </span>
          <h1 className="mx-auto mt-6 max-w-5xl text-4xl font-semibold tracking-tight sm:text-6xl lg:text-7xl lg:leading-[1.03]">
            Automatic TikTok livestream recording in the cloud.
          </h1>
          <p className="mx-auto mt-6 max-w-3xl text-base leading-7 text-[var(--muted)] sm:text-lg sm:leading-8">
            Add a channel once. SaveStream monitors it continuously and automatically records every livestream — even when your computer is offline.
          </p>
          <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
            <Link to="/sign-up" className={primaryButton}>
              Start for free <ArrowRight className="size-4" />
            </Link>
            <a href="#how" className={secondaryButton}>
              See how it works
            </a>
          </div>
          <p className="mt-3 text-xs text-[var(--muted)]">No credit card required.</p>

          <div className="mx-auto mt-12 max-w-[1380px] rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-2 shadow-2xl shadow-indigo-950/10 sm:mt-14 sm:p-3">
            <div className="rounded-xl border border-[var(--border)] bg-[var(--bg)] p-3 text-left sm:p-5 lg:p-6">
              <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <h2 className="font-semibold">Overview</h2>
                  <p className="text-xs text-[var(--muted)]">Your recording workspace</p>
                </div>
                <span className={`${primaryButton} w-full sm:w-auto`}>
                  <Plus className="size-4" /> Add channel
                </span>
              </div>
              <div className="mt-5 grid gap-px overflow-hidden rounded-lg border border-[var(--border)] bg-[var(--border)] sm:grid-cols-3">
                <Metric label="Recording hours" value="12.6 / 50 h" detail="25% used" />
                <Metric label="Active channels" value="3 / 5" detail="3 monitoring" />
                <Metric label="Stored" value="18.4 GB" detail="4 recordings" />
              </div>
              <div className="mt-5 rounded-xl border border-red-200 bg-red-50 p-4 dark:border-red-500/20 dark:bg-red-500/5 sm:p-5">
                <div className="flex items-center justify-between gap-3">
                  <span className="text-[11px] font-semibold text-red-600 sm:text-xs">● ACTIVE RECORDING</span>
                  <StatusBadge status="Recording" />
                </div>
                <div className="mt-5 flex flex-col gap-4 sm:flex-row sm:items-center">
                  <Avatar initials="LS" />
                  <div>
                    <b>Lina Studio</b>
                    <p className="text-sm text-[var(--muted)]">@linastudio · TikTok</p>
                  </div>
                  <div className="sm:ml-auto sm:text-right">
                    <p className="font-mono text-2xl font-semibold">01:42:18</p>
                    <p className="text-xs text-[var(--muted)]">3.8 GB written</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section id="how" className="border-b border-[var(--border)] py-16 sm:py-20">
          <div className="mx-auto max-w-[1440px] px-4 sm:px-6 lg:px-8">
            <p className="text-sm font-semibold text-indigo-600">How it works</p>
            <h2 className="mt-2 text-3xl font-semibold sm:text-4xl">Set it once. We handle the rest.</h2>
            <div className="mt-10 grid gap-px overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--border)] sm:grid-cols-2 xl:grid-cols-4">
              {[
                [Plus, "Add a channel", "Paste a TikTok username or profile URL."],
                [Radio, "We monitor it", "Cloud workers check the channel continuously."],
                [Video, "Recording starts", "Recording begins automatically when the channel goes live."],
                [Play, "Watch later", "The completed video appears in your library."],
              ].map(([Icon, title, body]) => {
                const I = Icon as typeof Plus;
                return (
                  <article key={String(title)} className="bg-[var(--surface)] p-6 lg:p-8">
                    <I className="size-5 text-indigo-600" />
                    <h3 className="mt-8 font-medium">{String(title)}</h3>
                    <p className="mt-2 text-sm leading-6 text-[var(--muted)]">{String(body)}</p>
                  </article>
                );
              })}
            </div>
          </div>
        </section>

        <section id="features" className="border-b border-[var(--border)] py-16 sm:py-20">
          <div className="mx-auto grid max-w-[1440px] gap-10 px-4 sm:px-6 md:grid-cols-[.8fr_1.2fr] lg:gap-16 lg:px-8">
            <div>
              <p className="text-sm font-semibold text-indigo-600">Cloud by design</p>
              <h2 className="mt-2 text-3xl font-semibold sm:text-4xl">Close your laptop. Recording continues.</h2>
              <p className="mt-4 max-w-xl text-[var(--muted)]">Monitoring and recording run on our servers, not in your browser.</p>
            </div>
            <div className="grid gap-px overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--border)] sm:grid-cols-2">
              {[
                "Automatic live detection",
                "Cloud recording",
                "Multiple monitored channels",
                "Recording library",
                "Browser playback",
                "Fast downloads",
                "Usage tracking",
                "Retention cleanup",
              ].map((item) => (
                <div key={item} className="flex items-center gap-3 bg-[var(--surface)] p-4 lg:p-5 text-sm">
                  <Check className="size-4 text-emerald-600" />
                  {item}
                </div>
              ))}
            </div>
          </div>
        </section>

        <section id="examples" className="border-b border-[var(--border)] py-16 sm:py-20">
          <div className="mx-auto max-w-[1440px] px-4 sm:px-6 lg:px-8">
            <div className="text-center">
              <p className="text-sm font-semibold text-indigo-600">Recording Examples</p>
              <h2 className="mt-2 text-3xl font-semibold sm:text-4xl">See what a completed cloud recording looks like.</h2>
            </div>
            <div className="mt-10 grid gap-5 md:grid-cols-3 lg:gap-6">
              {recordings.slice(0, 3).map((recording) => (
                <article key={recording.id} className="overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--surface)]">
                  <div className="relative aspect-video bg-gradient-to-br from-slate-950 via-indigo-950 to-violet-900">
                    <SaveStreamMark className="absolute left-1/2 top-1/2 size-14 -translate-x-1/2 -translate-y-1/2 opacity-60" />
                    <span className="absolute bottom-3 right-3 rounded bg-black/70 px-2 py-1 font-mono text-xs text-white">{recording.duration}</span>
                  </div>
                  <div className="p-5">
                    <div className="flex items-center justify-between gap-3">
                      <b>{recording.handle}</b>
                      <StatusBadge status="Ready" />
                    </div>
                    <p className="mt-2 text-sm text-[var(--muted)]">{recording.date} · {recording.resolution}</p>
                  </div>
                </article>
              ))}
            </div>
            <div className="mt-8 text-center">
              <Link to="/sign-up" className={primaryButton}>
                Start recording your own livestreams <ArrowRight className="size-4" />
              </Link>
            </div>
          </div>
        </section>

        <section className="px-4 py-16 text-center sm:px-6 sm:py-20">
          <h2 className="text-3xl font-semibold sm:text-4xl">Ready to stop missing livestreams?</h2>
          <p className="mx-auto mt-3 max-w-xl text-[var(--muted)]">Add your channels and let SaveStream record automatically in the cloud.</p>
          <Link to="/sign-up" className={`${primaryButton} mt-7`}>
            Sign up free
          </Link>
        </section>
      </main>

      <footer className="border-t border-[var(--border)] py-8">
        <div className="mx-auto flex max-w-[1540px] flex-col gap-4 px-4 text-sm text-[var(--muted)] sm:flex-row sm:items-center sm:px-6 lg:px-8">
          <Logo />
          <nav className="flex flex-wrap gap-5 sm:ml-auto">
            <Link to="/pricing">Pricing</Link>
            <Link to="/help">Help</Link>
            <Link to="/terms">Terms</Link>
            <Link to="/privacy">Privacy</Link>
            <Link to="/acceptable-use">Acceptable Use</Link>
          </nav>
        </div>
      </footer>
    </div>
  );
}

function Metric({ label, value, detail }: { label: string; value: string; detail: string }) {
  return (
    <div className="bg-[var(--surface)] p-4 sm:p-5 lg:p-6">
      <p className="text-sm text-[var(--muted)]">{label}</p>
      <p className="mt-2 font-mono text-xl font-semibold sm:text-2xl">{value}</p>
      <p className="mt-1 text-xs text-[var(--muted)]">{detail}</p>
    </div>
  );
}

function Avatar({ initials }: { initials: string }) {
  return <span className="grid size-11 shrink-0 place-items-center rounded-full bg-gradient-to-br from-fuchsia-500 to-rose-400 text-xs font-semibold text-white">{initials}</span>;
}
