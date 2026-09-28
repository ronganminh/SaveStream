import { Link } from "@tanstack/react-router";
import {
  ArrowRight,
  Check,
  Clock3,
  Cloud,
  ExternalLink,
  Play,
  Plus,
  Radio,
  Video,
  Youtube,
} from "lucide-react";
import { Logo, SaveStreamMark } from "./components/brand";
import { PreferencesControls } from "./components/preferences-controls";
import { StatusBadge } from "./components/ui";
import { recordings } from "./lib/mock-data";
import { usePreferences } from "./lib/preferences";

const primaryButton =
  "inline-flex h-10 items-center justify-center gap-2 rounded-lg bg-indigo-600 px-4 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-400";
const secondaryButton =
  "inline-flex h-10 items-center justify-center gap-2 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-4 text-sm font-semibold transition hover:bg-[var(--subtle)]";

function scrollToSection(id: string) {
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" });
}

export function LandingPage() {
  const { t } = usePreferences();
  const howSteps = [
    [Plus, t("how.add.title"), t("how.add.body")],
    [Radio, t("how.monitor.title"), t("how.monitor.body")],
    [Video, t("how.record.title"), t("how.record.body")],
    [Play, t("how.watch.title"), t("how.watch.body")],
  ] as const;
  const featureItems = [
    t("features.liveDetection"),
    t("features.cloudRecording"),
    t("features.multiChannel"),
    t("features.library"),
    t("features.playback"),
    t("features.downloads"),
    t("features.usage"),
    t("features.retention"),
  ];
  const partnerTiles = [t("partner.long"), t("partner.creator"), t("partner.review"), t("partner.library")];

  return (
    <div className="min-h-screen bg-[var(--bg)] text-[var(--fg)]">
      <header className="sticky top-0 z-30 border-b border-[var(--border)] bg-[color:var(--bg)]/90 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-[1540px] items-center px-3 sm:px-6 lg:px-8">
          <Logo />
          <nav className="ml-10 hidden items-center gap-7 text-sm text-[var(--muted)] lg:flex">
            <button type="button" onClick={() => scrollToSection("features")} className="transition hover:text-[var(--fg)]">{t("nav.features")}</button>
            <button type="button" onClick={() => scrollToSection("how")} className="transition hover:text-[var(--fg)]">{t("nav.how")}</button>
            <button type="button" onClick={() => scrollToSection("platforms")} className="transition hover:text-[var(--fg)]">{t("nav.platforms")}</button>
            <button type="button" onClick={() => scrollToSection("examples")} className="transition hover:text-[var(--fg)]">{t("nav.examples")}</button>
            <Link to="/pricing">{t("nav.pricing")}</Link>
          </nav>
          <div className="ml-auto flex items-center gap-1.5 sm:gap-2">
            <div className="hidden sm:block"><PreferencesControls compact /></div>
            <Link to="/sign-in" className="hidden h-10 items-center px-3 text-sm font-medium md:inline-flex">{t("nav.signIn")}</Link>
            <Link to="/sign-up" className={`${primaryButton} px-3 sm:px-4`}>{t("nav.signUp")}</Link>
          </div>
        </div>
      </header>

      <main>
        <section className="flex flex-col items-center border-b border-[var(--border)] px-4 pb-16 pt-16 text-center sm:pb-20 sm:pt-20 lg:px-8 lg:pb-24 lg:pt-24">
          <span className="inline-flex items-center gap-2 rounded-full border border-[var(--border)] bg-[var(--surface)] px-3 py-1 text-xs text-[var(--muted)]">
            <Cloud className="size-3 text-indigo-600" /> {t("hero.badge")}
          </span>
          <h1 className="mx-auto mt-6 max-w-5xl text-4xl font-semibold tracking-tight sm:text-6xl lg:text-7xl lg:leading-[1.03]">{t("hero.title")}</h1>
          <p className="mx-auto mt-6 max-w-3xl text-base leading-7 text-[var(--muted)] sm:text-lg sm:leading-8">{t("hero.body")}</p>
          <div className="mt-8 flex w-full max-w-md flex-col justify-center gap-3 sm:w-auto sm:max-w-none sm:flex-row">
            <Link to="/sign-up" className={primaryButton}>{t("cta.startRecording")} <ArrowRight className="size-4" /></Link>
            <button type="button" onClick={() => scrollToSection("how")} className={secondaryButton}>{t("cta.seeHow")}</button>
          </div>
          <p className="mt-3 text-xs text-[var(--muted)]">{t("hero.noCard")}</p>

          <div className="mx-auto mt-12 w-full max-w-[1380px] rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-2 shadow-2xl shadow-indigo-950/10 sm:mt-14 sm:p-3">
            <div className="rounded-xl border border-[var(--border)] bg-[var(--bg)] p-3 text-left sm:p-5 lg:p-6">
              <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div><h2 className="font-semibold">{t("preview.overview")}</h2><p className="text-xs text-[var(--muted)]">{t("preview.workspace")}</p></div>
                <span className={`${primaryButton} w-full sm:w-auto`}><Plus className="size-4" /> {t("preview.addChannel")}</span>
              </div>
              <div className="mt-5 grid gap-px overflow-hidden rounded-lg border border-[var(--border)] bg-[var(--border)] sm:grid-cols-3">
                <Metric label={t("preview.recordingHours")} value="12.6 / 50 h" detail={t("preview.used")} />
                <Metric label={t("preview.activeChannels")} value="3 / 5" detail={t("preview.monitoring")} />
                <Metric label={t("preview.stored")} value="18.4 GB" detail={t("preview.recordings")} />
              </div>
              <div className="mt-5 rounded-xl border border-red-200 bg-red-50 p-4 dark:border-red-500/20 dark:bg-red-500/5 sm:p-5">
                <div className="flex items-center justify-between gap-3"><span className="text-[11px] font-semibold text-red-600 sm:text-xs">● {t("preview.activeRecording")}</span><StatusBadge status="Recording" /></div>
                <div className="mt-5 flex flex-col gap-4 sm:flex-row sm:items-center">
                  <Avatar initials="LS" />
                  <div><b>Lina Studio</b><p className="text-sm text-[var(--muted)]">@linastudio · TikTok</p></div>
                  <div className="sm:ml-auto sm:text-right"><p className="font-mono text-2xl font-semibold">01:42:18</p><p className="text-xs text-[var(--muted)]">{t("preview.written")}</p></div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section id="how" className="border-b border-[var(--border)] py-16 sm:py-20">
          <div className="mx-auto max-w-[1440px] px-4 sm:px-6 lg:px-8">
            <p className="text-sm font-semibold text-indigo-600">{t("how.eyebrow")}</p>
            <h2 className="mt-2 text-3xl font-semibold sm:text-4xl">{t("how.title")}</h2>
            <div className="mt-10 grid gap-px overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--border)] sm:grid-cols-2 xl:grid-cols-4">
              {howSteps.map(([Icon, title, body]) => (
                <article key={title} className="bg-[var(--surface)] p-6 lg:p-8"><Icon className="size-5 text-indigo-600" /><h3 className="mt-8 font-medium">{title}</h3><p className="mt-2 text-sm leading-6 text-[var(--muted)]">{body}</p></article>
              ))}
            </div>
          </div>
        </section>

        <section id="features" className="border-b border-[var(--border)] py-16 sm:py-20">
          <div className="mx-auto grid max-w-[1440px] gap-10 px-4 sm:px-6 md:grid-cols-[.8fr_1.2fr] lg:gap-16 lg:px-8">
            <div><p className="text-sm font-semibold text-indigo-600">{t("features.eyebrow")}</p><h2 className="mt-2 text-3xl font-semibold sm:text-4xl">{t("features.title")}</h2><p className="mt-4 max-w-xl text-[var(--muted)]">{t("features.body")}</p></div>
            <div className="grid gap-px overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--border)] sm:grid-cols-2">
              {featureItems.map((item) => <div key={item} className="flex items-center gap-3 bg-[var(--surface)] p-4 text-sm lg:p-5"><Check className="size-4 text-emerald-600" />{item}</div>)}
            </div>
          </div>
        </section>

        <section id="platforms" className="border-b border-[var(--border)] py-16 sm:py-20">
          <div className="mx-auto max-w-[1440px] px-4 sm:px-6 lg:px-8">
            <div className="max-w-3xl"><p className="text-sm font-semibold text-indigo-600">{t("platforms.eyebrow")}</p><h2 className="mt-2 text-3xl font-semibold sm:text-4xl">{t("platforms.title")}</h2><p className="mt-4 text-[var(--muted)]">{t("platforms.body")}</p></div>
            <div className="mt-10 grid gap-5 md:grid-cols-2">
              <PlatformCard icon={<Radio className="size-6" />} tone="indigo" status={t("platforms.available")} title="TikTok Live" body={t("platforms.tiktok.body")} />
              <PlatformCard icon={<Clock3 className="size-6" />} tone="amber" status={t("platforms.planned")} title="Douyin Live" body={t("platforms.douyin.body")} />
            </div>
          </div>
        </section>

        <section id="examples" className="border-b border-[var(--border)] py-16 sm:py-20">
          <div className="mx-auto max-w-[1440px] px-4 sm:px-6 lg:px-8">
            <div className="text-center"><p className="text-sm font-semibold text-indigo-600">{t("examples.eyebrow")}</p><h2 className="mt-2 text-3xl font-semibold sm:text-4xl">{t("examples.title")}</h2></div>
            <div className="mt-10 grid gap-5 md:grid-cols-3 lg:gap-6">
              {recordings.slice(0, 3).map((recording) => (
                <article key={recording.id} className="overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--surface)]">
                  <div className="relative aspect-video bg-gradient-to-br from-slate-950 via-indigo-950 to-violet-900"><SaveStreamMark className="absolute left-1/2 top-1/2 size-14 -translate-x-1/2 -translate-y-1/2 opacity-60" /><span className="absolute bottom-3 right-3 rounded bg-black/70 px-2 py-1 font-mono text-xs text-white">{recording.duration}</span></div>
                  <div className="p-5"><div className="flex items-center justify-between gap-3"><b>{recording.handle}</b><StatusBadge status="Ready" /></div><p className="mt-2 text-sm text-[var(--muted)]">{recording.date} · {recording.resolution}</p></div>
                </article>
              ))}
            </div>
            <div className="mt-8 text-center"><Link to="/sign-up" className={primaryButton}>{t("cta.startRecording")} <ArrowRight className="size-4" /></Link></div>
          </div>
        </section>

        <section id="partner" className="border-b border-[var(--border)] py-16 sm:py-20">
          <div className="mx-auto max-w-[1440px] px-4 sm:px-6 lg:px-8">
            <div className="overflow-hidden rounded-2xl border border-[var(--border)] bg-[var(--surface)]">
              <div className="grid lg:grid-cols-[1fr_.95fr]">
                <div className="p-6 sm:p-10 lg:p-12"><p className="text-sm font-semibold text-indigo-600">{t("partner.eyebrow")}</p><h2 className="mt-2 max-w-2xl text-3xl font-semibold sm:text-4xl">{t("partner.title")}</h2><p className="mt-5 max-w-2xl leading-7 text-[var(--muted)]">{t("partner.body")}</p><a href="https://www.youtube.com/channel/UCUkhUF-GUS22KWBFEcD2fEw" target="_blank" rel="noreferrer" className={`${primaryButton} mt-7`}><Youtube className="size-4" /> {t("cta.visitPartner")} <ExternalLink className="size-4" /></a></div>
                <div className="grid min-h-72 grid-cols-2 gap-px bg-[var(--border)] p-px sm:min-h-80">
                  {partnerTiles.map((label, index) => <div key={label} className="relative grid place-items-center overflow-hidden bg-gradient-to-br from-slate-950 via-indigo-950 to-violet-900 p-6 text-center text-white"><Youtube className="size-9 text-white/70" /><p className="mt-3 text-sm font-medium">{label}</p><span className="absolute right-3 top-3 font-mono text-xs text-white/45">0{index + 1}</span></div>)}
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="px-4 py-16 text-center sm:px-6 sm:py-20"><h2 className="text-3xl font-semibold sm:text-4xl">{t("bottom.title")}</h2><p className="mx-auto mt-3 max-w-xl text-[var(--muted)]">{t("bottom.body")}</p><Link to="/sign-up" className={`${primaryButton} mt-7`}>{t("cta.startRecording")}</Link></section>
      </main>

      <footer className="border-t border-[var(--border)] py-8">
        <div className="mx-auto flex max-w-[1540px] flex-col gap-4 px-4 text-sm text-[var(--muted)] sm:flex-row sm:items-center sm:px-6 lg:px-8">
          <Logo />
          <nav className="flex flex-wrap gap-5 sm:ml-auto"><Link to="/pricing">{t("nav.pricing")}</Link><Link to="/help">{t("footer.help")}</Link><Link to="/terms">{t("footer.terms")}</Link><Link to="/privacy">{t("footer.privacy")}</Link><Link to="/acceptable-use">{t("footer.acceptable")}</Link></nav>
        </div>
      </footer>
    </div>
  );
}

function Metric({ label, value, detail }: { label: string; value: string; detail: string }) {
  return <div className="bg-[var(--surface)] p-4 sm:p-5 lg:p-6"><p className="text-sm text-[var(--muted)]">{label}</p><p className="mt-2 font-mono text-xl font-semibold sm:text-2xl">{value}</p><p className="mt-1 text-xs text-[var(--muted)]">{detail}</p></div>;
}

function Avatar({ initials }: { initials: string }) {
  return <span className="grid size-11 shrink-0 place-items-center rounded-full bg-gradient-to-br from-fuchsia-500 to-rose-400 text-xs font-semibold text-white">{initials}</span>;
}

function PlatformCard({ icon, tone, status, title, body }: { icon: React.ReactNode; tone: "indigo" | "amber"; status: string; title: string; body: string }) {
  const toneClass = tone === "indigo" ? "bg-indigo-50 text-indigo-600 dark:bg-indigo-500/10 dark:text-indigo-300" : "bg-amber-50 text-amber-700 dark:bg-amber-500/10 dark:text-amber-300";
  const statusClass = tone === "indigo" ? "border-emerald-200 bg-emerald-50 text-emerald-700 dark:border-emerald-500/20 dark:bg-emerald-500/10 dark:text-emerald-300" : "border-amber-200 bg-amber-50 text-amber-700 dark:border-amber-500/20 dark:bg-amber-500/10 dark:text-amber-300";
  return <article className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-6 sm:p-8"><div className="flex items-start justify-between gap-4"><span className={`grid size-12 place-items-center rounded-xl ${toneClass}`}>{icon}</span><span className={`rounded-full border px-3 py-1 text-xs font-semibold ${statusClass}`}>{status}</span></div><h3 className="mt-8 text-xl font-semibold">{title}</h3><p className="mt-3 text-sm leading-6 text-[var(--muted)]">{body}</p></article>;
}
