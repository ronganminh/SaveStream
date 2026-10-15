import { Link } from "@tanstack/react-router";
import { useMemo } from "react";
import {
  ArrowRight,
  Bell,
  Cloud,
  Download,
  Layers,
  Plus,
  Radio,
  ShieldCheck,
  Smartphone,
  Store,
  Users,
  Video,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { formatMoneyValue, formatRecordingTime } from "@/components/app-pages";
import { JsonLd, PublicFrame, StartRecordingCta } from "@/components/public/guides-pages";
import { useAuth } from "@/auth/auth-context";
import { usePublicPricingData } from "@/hooks/use-domain-data";
import { faqPageData, guides } from "@/lib/guides-content";
import { helpVariables } from "@/lib/help-content";
import { packHours, retentionSentence } from "@/lib/plan-facts";
import { PUBLIC_SITE_URL } from "@/lib/route-metadata";
import { cn } from "@/lib/utils";

const eyebrow = "text-[13px] font-bold uppercase tracking-[.08em] text-accent-ink";
const sectionTitle =
  "text-[clamp(28px,3.2vw,40px)] font-extrabold leading-[1.1] tracking-[-.025em] text-balance";
const lead = "text-lg leading-relaxed text-muted-foreground";
const card = "rounded-2xl border bg-surface shadow-card";

/** SEO landing page for "TikTok LIVE recorder" / "record TikTok live automatically". */
export function TikTokLiveRecorderPage() {
  const { status } = useAuth();
  const startTo = status === "authenticated" ? "/overview" : "/sign-up";
  const { query } = usePublicPricingData();
  const pricing = query.data;
  const vars = helpVariables(pricing);
  const cheapest = pricing?.packages.length
    ? [...pricing.packages].sort((a, b) => a.price.amount_minor - b.price.amount_minor)[0]
    : undefined;
  const cheapestHours = cheapest ? packHours(cheapest) : null;

  const faqs = useMemo(
    () => [
      {
        question: "What is a TikTok LIVE recorder?",
        answer:
          "A TikTok LIVE recorder saves a copy of a livestream while it is happening, because TikTok LIVEs are not kept in the app once they end. SaveStream does this in the cloud: it watches the channels you add and records them on its servers when they go live.",
      },
      {
        question: "Can it record TikTok LIVE automatically?",
        answer:
          "Yes. After your first credit purchase, switch on Auto-record for a channel. SaveStream checks it about every 30 seconds and starts recording on its own when the channel goes live, even if your phone and computer are off.",
      },
      {
        question: "Do I need to keep my computer or phone on?",
        answer:
          "No. Recording runs on SaveStream's servers. You can close the browser, shut down your computer and go live from your phone; the recording still happens.",
      },
      {
        question: "How much does it cost?",
        answer: `Checking channels is free. Recording is paid with credits at ${vars.credit_rate}, bought in one-time packs that never expire. New accounts receive ${vars.signup_credits}. Current packs are on the Pricing page.`,
      },
      {
        question: "How long are recordings kept?",
        answer: `${retentionSentence(pricing)}. You can watch them in the browser or download them as MP4 files at any time before they expire.`,
      },
      {
        question: "Which channels can I record?",
        answer:
          "Only channels you own, manage, or have clear permission from the creator to record. Adding a channel confirms you have that right, and channels that break the Acceptable Use Policy may be removed.",
      },
    ],
    [vars.credit_rate, vars.signup_credits, pricing],
  );

  const structured = useMemo(
    () => ({
      "@context": "https://schema.org",
      "@graph": [
        {
          "@type": "SoftwareApplication",
          name: "SaveStream",
          applicationCategory: "MultimediaApplication",
          operatingSystem: "Web",
          url: `${PUBLIC_SITE_URL}/tiktok-live-recorder`,
          description:
            "Cloud TikTok LIVE recorder that records your own channels automatically when they go live.",
        },
        faqPageData(faqs),
      ],
    }),
    [faqs],
  );

  return (
    <PublicFrame>
      <JsonLd data={structured} />

      {/* Hero */}
      <section className="relative overflow-hidden border-b">
        <div aria-hidden className="hero-glow" />
        <div className="relative mx-auto flex max-w-[960px] flex-col items-center gap-6 px-6 pb-20 pt-20 text-center">
          <span className="inline-flex items-center gap-2 rounded-full border bg-surface px-3 py-1 text-sm font-medium shadow-card">
            <Cloud className="size-4 text-primary" />
            TikTok LIVE recorder
          </span>
          <h1 className="text-[clamp(38px,5vw,60px)] font-extrabold leading-[1.04] tracking-[-.04em] text-balance">
            Record TikTok LIVE automatically, even when you’re offline
          </h1>
          <p className={cn(lead, "max-w-[640px]")}>
            SaveStream is a cloud TikTok LIVE recorder for creators and sellers. Add your channel
            once, and every LIVE is recorded on our servers and saved as an MP4 you can watch or
            download.
          </p>
          <div className="flex flex-wrap justify-center gap-3">
            <Button size="lg" asChild>
              <Link to={startTo}>
                Start recording your channel
                <ArrowRight />
              </Link>
            </Button>
            <Button size="lg" variant="outline" asChild>
              <Link to="/pricing">See pricing</Link>
            </Button>
          </div>
          <p className="text-sm text-muted-foreground">
            No payment to sign up · Credits never expire · No subscription
          </p>
        </div>
      </section>

      {/* How it works */}
      <section className="border-b py-20" aria-labelledby="how-title">
        <div className="mx-auto max-w-[1200px] px-6">
          <div className="flex max-w-2xl flex-col gap-3">
            <span className={eyebrow}>How it works</span>
            <h2 id="how-title" className={sectionTitle}>
              Set up once, then forget about the record button
            </h2>
          </div>
          <ol className="mt-10 grid gap-5 md:grid-cols-4">
            {(
              [
                [Plus, "Add your channel", "Enter your TikTok username or profile link."],
                [
                  Radio,
                  "We watch it",
                  "SaveStream checks the channel about every 30 seconds from the cloud.",
                ],
                [
                  Video,
                  "Recording starts",
                  "With Auto-record on, recording begins on its own when you go live.",
                ],
                [Download, "Watch or download", "Play it in the browser or save the MP4."],
              ] as const
            ).map(([Icon, title, body], index) => (
              <li key={title} className={cn(card, "flex flex-col gap-3 p-6")}>
                <span className="font-mono text-xs text-muted-foreground">0{index + 1}</span>
                <span className="grid size-10 place-items-center rounded-xl bg-primary-subtle text-accent-ink">
                  <Icon className="size-5" />
                </span>
                <h3 className="mt-1 font-bold">{title}</h3>
                <p className="text-sm leading-6 text-muted-foreground">{body}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* Why cloud */}
      <section className="border-b py-20" aria-labelledby="why-title">
        <div className="mx-auto grid max-w-[1200px] gap-12 px-6 lg:grid-cols-[1fr_1.1fr]">
          <div className="flex flex-col gap-4">
            <span className={eyebrow}>Why record in the cloud</span>
            <h2 id="why-title" className={sectionTitle}>
              Manual recording ties up a device for hours
            </h2>
            <p className={lead}>
              Screen recording works for a one-off stream, but the device has to stay awake,
              connected and charged for the whole LIVE, and someone has to press record. A cloud
              recorder runs on a server that is always on, so it catches LIVEs you start from your
              phone, late at night or at short notice.
            </p>
            <Link
              to="/guides/$guide"
              params={{ guide: "how-to-record-a-tiktok-live" }}
              className="font-semibold text-accent-ink"
            >
              Compare all three ways to record a TikTok LIVE →
            </Link>
          </div>
          <ul className="grid gap-4 sm:grid-cols-2">
            {(
              [
                [
                  Cloud,
                  "Nothing stays on",
                  "Your phone and computer can be off while you’re live.",
                ],
                [Video, "Original quality", "Recordings keep TikTok’s vertical format."],
                [Download, "MP4 downloads", "Files are named by channel and start time."],
                [
                  Layers,
                  "Several channels",
                  `Record ${vars.parallel_recordings} at the same time.`,
                ],
                [
                  Bell,
                  "Alerts",
                  "Get notified when a channel goes live and when a recording is ready.",
                ],
                [
                  ShieldCheck,
                  "Fair billing",
                  "Pay only for recorded time; failed or missed recordings aren’t charged.",
                ],
              ] as const
            ).map(([Icon, title, body]) => (
              <li key={title} className={cn(card, "flex flex-col gap-2 p-5")}>
                <Icon className="size-5 text-accent-ink" />
                <b>{title}</b>
                <span className="text-sm leading-6 text-muted-foreground">{body}</span>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* Who it's for */}
      <section className="border-b py-20" aria-labelledby="who-title">
        <div className="mx-auto max-w-[1200px] px-6">
          <div className="flex max-w-2xl flex-col gap-3">
            <span className={eyebrow}>Who it’s for</span>
            <h2 id="who-title" className={sectionTitle}>
              Built for people who record their own LIVEs
            </h2>
          </div>
          <div className="mt-10 grid gap-5 md:grid-cols-3">
            {(
              [
                [
                  Smartphone,
                  "Creators",
                  "Keep every stream to rewatch, archive or cut into clips.",
                  "turn-tiktok-live-into-clips",
                  "Turn a LIVE into clips",
                ],
                [
                  Store,
                  "LIVE sellers",
                  "Keep a record of product demos, offers and answers from every sales LIVE.",
                  "tiktok-live-sellers-keep-recordings",
                  "A recording system for sellers",
                ],
                [
                  Users,
                  "Managers and teams",
                  "Record the channels you run for a creator or brand, with their permission.",
                  "record-tiktok-live-without-computer-on",
                  "Record without a computer on",
                ],
              ] as const
            ).map(([Icon, title, body, slug, linkText]) => (
              <article key={title} className={cn(card, "flex flex-col gap-3 p-6")}>
                <span className="grid size-10 place-items-center rounded-xl bg-primary-subtle text-accent-ink">
                  <Icon className="size-5" />
                </span>
                <h3 className="text-lg font-bold">{title}</h3>
                <p className="flex-1 text-sm leading-6 text-muted-foreground">{body}</p>
                <Link
                  to="/guides/$guide"
                  params={{ guide: slug }}
                  className="text-sm font-semibold text-accent-ink"
                >
                  {linkText} →
                </Link>
              </article>
            ))}
          </div>
        </div>
      </section>

      {/* Pricing snapshot */}
      <section className="border-b py-20" aria-labelledby="price-title">
        <div className="mx-auto flex max-w-[960px] flex-col items-center gap-4 px-6 text-center">
          <span className={eyebrow}>Pricing</span>
          <h2 id="price-title" className={sectionTitle}>
            Pay only for the time you record
          </h2>
          <p className={cn(lead, "max-w-2xl")}>
            Checking channels is free. Recording uses credits at {vars.credit_rate}, bought in
            one-time packs that never expire.
            {cheapest
              ? ` Packs start at ${formatMoneyValue(cheapest.price, "en")}${
                  cheapestHours !== null
                    ? ` for ${formatRecordingTime(Math.round(cheapestHours * 60))} of recording`
                    : ""
                }.`
              : ""}{" "}
            New accounts receive {vars.signup_credits}.
          </p>
          <Button variant="outline" asChild>
            <Link to="/pricing">
              See all packs
              <ArrowRight />
            </Link>
          </Button>
        </div>
      </section>

      {/* Permission */}
      <section aria-label="Responsible use" className="mx-auto max-w-[1200px] px-6 pt-16">
        <div className="flex flex-wrap items-center gap-4 rounded-2xl border border-info/25 bg-info-subtle px-6 py-5">
          <ShieldCheck className="size-6 flex-none text-info" />
          <div className="flex min-w-[240px] flex-1 flex-col gap-1">
            <b>Only record channels you have the right to record</b>
            <span className="text-sm text-muted-foreground">
              Add your own channel, a channel you manage, or one whose creator has given you clear
              permission. SaveStream is not a tool for collecting other people’s streams.
            </span>
          </div>
          <Link to="/acceptable-use" className="text-sm font-semibold text-accent-ink">
            Read the Acceptable Use Policy →
          </Link>
        </div>
      </section>

      {/* FAQ */}
      <section className="mx-auto max-w-[860px] px-6 pt-20" aria-labelledby="faq-title">
        <div className="mb-8 flex flex-col items-center gap-3 text-center">
          <span className={eyebrow}>FAQ</span>
          <h2 id="faq-title" className={sectionTitle}>
            TikTok LIVE recorder questions
          </h2>
        </div>
        <div className="flex flex-col gap-3">
          {faqs.map((item) => (
            <details key={item.question} className="group rounded-2xl border bg-surface">
              <summary className="flex min-h-16 cursor-pointer list-none items-center justify-between gap-4 px-[22px] py-[18px] text-[17px] font-semibold hover:text-accent-ink">
                <h3>{item.question}</h3>
                <span
                  aria-hidden
                  className="text-muted-foreground transition-transform group-open:rotate-45"
                >
                  +
                </span>
              </summary>
              <p className="px-[22px] pb-[22px] leading-relaxed text-muted-foreground">
                {item.answer}
              </p>
            </details>
          ))}
        </div>
      </section>

      {/* Guides */}
      <section className="mx-auto max-w-[1200px] px-6 pt-20" aria-labelledby="guides-title">
        <div className="mb-6 flex flex-wrap items-end justify-between gap-3">
          <h2 id="guides-title" className="text-[24px] font-bold tracking-[-.015em]">
            Guides
          </h2>
          <Link to="/guides" className="text-sm font-semibold text-accent-ink">
            All guides →
          </Link>
        </div>
        <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {guides.map((item) => (
            <li key={item.slug}>
              <Link
                to="/guides/$guide"
                params={{ guide: item.slug }}
                className="flex h-full flex-col gap-1 rounded-2xl border bg-surface p-4 transition hover:-translate-y-0.5 hover:border-primary/40"
              >
                <b className="text-sm">{item.title}</b>
                <span className="text-xs text-muted-foreground">{item.summary}</span>
              </Link>
            </li>
          ))}
        </ul>
      </section>

      <section className="mx-auto max-w-[1200px] px-6 pt-16">
        <StartRecordingCta title="Start recording your TikTok LIVEs" />
      </section>
    </PublicFrame>
  );
}
