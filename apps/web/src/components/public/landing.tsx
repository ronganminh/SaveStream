import { Link } from "@tanstack/react-router";
import { useState } from "react";
import {
  ArrowRight,
  BarChart3,
  Check,
  ChevronDown,
  Cloud,
  Download,
  Play,
  Plus,
  Radio,
  ShieldCheck,
  Video,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  PublicFooter,
  PublicHeader,
  RecordingExamples,
  formatMoneyValue,
  formatRecordingTime,
} from "@/components/app-pages";
import { useAuth } from "@/auth/auth-context";
import { usePublicPricingData } from "@/hooks/use-domain-data";
import { pluralize } from "@/lib/formatters";
import { packHours, retentionSentence } from "@/lib/plan-facts";
import { PUBLIC_SITE_URL } from "@/lib/route-metadata";
import { cn } from "@/lib/utils";

const eyebrow = "text-[13px] font-bold uppercase tracking-[.08em] text-accent-ink";
const sectionTitle =
  "text-[clamp(30px,3.4vw,44px)] font-extrabold leading-[1.1] tracking-[-.025em] text-balance";
const lead = "text-lg leading-relaxed text-muted-foreground";
const card = "rounded-2xl border bg-surface shadow-card";

/** Production landing page (design "SaveStream Landing Redesign", desktop). */
export function ProductionLanding() {
  const { status } = useAuth();
  const authenticated = status === "authenticated";
  const { query } = usePublicPricingData();
  const pricing = query.data;
  const startTo = authenticated ? "/overview" : "/sign-up";
  const paidDays = pricing?.recording_retention_days;
  const proChannels = pricing?.max_channels_per_user;
  const parallel = pricing?.max_concurrent_recordings_per_user;

  const structuredData = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "SaveStream",
    applicationCategory: "MultimediaApplication",
    operatingSystem: "Web",
    url: PUBLIC_SITE_URL,
    description: "Cloud monitoring and recording for authorized TikTok livestream workflows.",
  };

  const trust = [
    "No payment to sign up",
    "Credits never expire",
    paidDays ? `Stored up to ${pluralize(paidDays, "day")}` : "Watch or download anytime",
  ];

  return (
    <div className="min-h-screen bg-background">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />
      <PublicHeader />
      <main className="pt-[72px]">
        {/* Hero */}
        <section className="relative overflow-hidden border-b">
          <div aria-hidden className="hero-glow" />
          <div className="relative mx-auto grid max-w-[1200px] items-center gap-14 px-6 pb-24 pt-20 lg:grid-cols-[1.05fr_1fr]">
            <div className="flex flex-col items-start gap-6">
              <a
                href="#how"
                className="inline-flex items-center gap-2 rounded-full border bg-surface px-1.5 py-1 pr-3 text-sm font-medium shadow-card"
              >
                <span className="rounded-full bg-primary-subtle px-2 py-0.5 text-xs font-bold text-accent-ink">
                  Cloud
                </span>
                <span>Recording runs on our servers, not your device</span>
              </a>
              <h1 className="text-[clamp(40px,5vw,64px)] font-extrabold leading-[1.03] tracking-[-.04em] text-balance">
                Never miss a TikTok <span className="text-primary">LIVE</span> again.
              </h1>
              <p className={cn(lead, "max-w-[560px]")}>
                SaveStream watches the TikTok channels you are authorized to record and saves every
                livestream in the cloud. No computer or browser needs to stay open.
              </p>
              <div className="flex flex-wrap gap-3">
                <Button size="lg" asChild>
                  <Link to={startTo}>
                    {authenticated ? "Open dashboard" : "Start for free"}
                    <ArrowRight />
                  </Link>
                </Button>
                <Button size="lg" variant="outline" asChild>
                  <a href="#examples">
                    <Play />
                    Watch a sample
                  </a>
                </Button>
              </div>
              <ul className="flex flex-wrap gap-x-5 gap-y-2 text-sm text-muted-foreground">
                {trust.map((item) => (
                  <li key={item} className="flex items-center gap-2">
                    <Check className="size-4 text-success" />
                    {item}
                  </li>
                ))}
              </ul>
            </div>
            <HeroMockup />
          </div>
        </section>

        {/* How it works */}
        <section id="how" className="scroll-mt-20 border-b py-24">
          <div className="mx-auto max-w-[1200px] px-6">
            <div className="flex max-w-2xl flex-col gap-3">
              <span className={eyebrow}>How it works</span>
              <h2 className={sectionTitle}>Set it once. We handle the rest.</h2>
            </div>
            <ol className="mt-12 grid gap-5 md:grid-cols-4">
              {(
                [
                  [Plus, "Add a channel", "Enter a TikTok username or profile link."],
                  [
                    Radio,
                    "We watch it",
                    "SaveStream checks the channel’s live status from the cloud, around the clock.",
                  ],
                  [
                    Video,
                    "Recording starts",
                    "With Auto-record on, recording starts by itself when the channel goes live.",
                  ],
                  [Play, "Watch later", "Play it in the browser or download the video."],
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

        {/* Features */}
        <section id="features" className="scroll-mt-20 border-b py-24">
          <div className="mx-auto max-w-[1200px] px-6">
            <div className="flex max-w-2xl flex-col gap-3">
              <span className={eyebrow}>Features</span>
              <h2 className={sectionTitle}>Close your laptop. Recording continues.</h2>
              <p className={lead}>
                Detection and recording run in the cloud, so nothing on your side needs to stay on —
                no laptops left running overnight, no scrambling to hit record.
              </p>
            </div>
            <div className="mt-12 grid gap-5 md:grid-cols-6">
              <Feature
                className="md:col-span-4"
                icon={Radio}
                title="Automatic live detection"
                body="Channels are checked about every 20 seconds, so a LIVE is noticed within a minute of starting. Checking offline channels is free."
              />
              <Feature
                className="md:col-span-2"
                icon={Cloud}
                title="Cloud recording"
                body="Close the laptop. Turn off the phone. Recording happens on our servers, not your device."
              />
              <Feature
                className="md:col-span-2"
                icon={BarChart3}
                title="Multi-channel monitoring"
                body={
                  proChannels
                    ? `Watch up to ${pluralize(proChannels, "channel")} from one dashboard${parallel ? `, recording up to ${parallel} at once` : ""}.`
                    : "Watch your main and backup accounts from one dashboard."
                }
              />
              <Feature
                className="md:col-span-2"
                icon={Play}
                title="In-browser playback"
                body="Check any recording in the browser. No download needed."
              />
              <Feature
                className="md:col-span-2"
                icon={Download}
                title="Downloads"
                body="Save the MP4 at its original recorded quality, ready for editing."
              />
              <Feature
                className="md:col-span-6"
                icon={BarChart3}
                title="Credit usage history"
                body="See which stream used how many credits, what is held for running recordings and what was released. No surprises."
              />
            </div>
          </div>
        </section>

        <RecordingExamples />

        {/* Why SaveStream */}
        <section id="why" className="border-b py-24">
          <div className="mx-auto grid max-w-[1200px] items-center gap-14 px-6 lg:grid-cols-2">
            <div className="flex flex-col gap-4">
              <span className={eyebrow}>Why SaveStream</span>
              <h2 className={sectionTitle}>Pay for what you record. Nothing more.</h2>
              <p className={lead}>
                Credit packs sit in your account until you need them — no monthly fee whether you
                stream or not.
              </p>
              <ul className="mt-2 flex flex-col gap-4">
                {(
                  [
                    ["Credits never expire", "Take a month off. Your credits are still there."],
                    [
                      "Checking offline channels is free",
                      "Credits are only used while a LIVE is being recorded.",
                    ],
                    [
                      "Failed recordings aren’t charged",
                      "If no usable video is saved, the held credits go back to your balance.",
                    ],
                  ] as const
                ).map(([title, body]) => (
                  <li key={title} className="flex gap-3">
                    <span className="grid size-7 flex-none place-items-center rounded-lg bg-success-subtle text-success">
                      <Check className="size-4" />
                    </span>
                    <span className="flex flex-col">
                      <b>{title}</b>
                      <span className="text-sm text-muted-foreground">{body}</span>
                    </span>
                  </li>
                ))}
              </ul>
            </div>
            <div className={cn(card, "overflow-hidden")}>
              <table className="w-full text-[15px]">
                <caption className="sr-only">
                  SaveStream compared with typical monthly subscription recorders
                </caption>
                <thead>
                  <tr className="border-b text-left text-sm">
                    <th scope="col" className="px-5 py-3.5" />
                    <th scope="col" className="px-5 py-3.5 text-accent-ink">
                      SaveStream
                    </th>
                    <th scope="col" className="px-5 py-3.5 text-muted-foreground">
                      Monthly subscriptions
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {(
                    [
                      ["Billing", "One-time credit packs", "Recurring fee"],
                      ["Unused time", "Never expires", "Resets each cycle"],
                      ["Offline monitoring", "Free", "Included in fee"],
                      ["Storage", paidDays ? pluralize(paidDays, "day") : "Limited time", "Varies"],
                      [
                        "Try it first",
                        pricing?.signup_credits
                          ? `${pricing.signup_credits} free credits`
                          : "Free account",
                        "Varies",
                      ],
                    ] as const
                  ).map(([label, ours, theirs]) => (
                    <tr key={label} className="border-b last:border-0">
                      <th scope="row" className="px-5 py-3.5 text-left font-semibold">
                        {label}
                      </th>
                      <td className="px-5 py-3.5 font-medium">{ours}</td>
                      <td className="px-5 py-3.5 text-muted-foreground">{theirs}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </section>

        {/* Pricing preview */}
        <section id="pricing" className="scroll-mt-20 border-b py-24">
          <div className="mx-auto max-w-[1200px] px-6">
            <div className="flex flex-col items-center gap-3 text-center">
              <span className={eyebrow}>Pricing</span>
              <h2 className={sectionTitle}>Pay as you go with credits.</h2>
              <p className={cn(lead, "max-w-2xl")}>
                Buy a credit pack once and use it whenever your channels go live. No subscription.
              </p>
            </div>
            {pricing?.packages.length ? (
              <div className="mt-12 grid gap-6 md:grid-cols-3">
                {pricing.packages.map((item) => {
                  const hours = packHours(item);
                  return (
                    <article key={item.id} className={cn(card, "flex flex-col gap-4 p-7")}>
                      <h3 className="text-[21px] font-bold">{item.name}</h3>
                      <div className="flex items-baseline gap-2">
                        <span className="text-[44px] font-extrabold tracking-[-.04em]">
                          {formatMoneyValue(item.price, "en")}
                        </span>
                        <span className="text-muted-foreground">one time</span>
                      </div>
                      <p className="rounded-xl bg-surface-2 px-4 py-3 font-bold">
                        {hours !== null
                          ? formatRecordingTime(Math.round(hours * 60))
                          : `${item.credits.toLocaleString("en")} credits`}
                      </p>
                    </article>
                  );
                })}
              </div>
            ) : null}
            <div className="mt-10 flex justify-center">
              <Button size="lg" variant="outline" asChild>
                <Link to={authenticated ? "/billing" : "/pricing"}>
                  {authenticated ? "Buy credits" : "See pricing"}
                  <ArrowRight />
                </Link>
              </Button>
            </div>
          </div>
        </section>

        {/* Responsible use */}
        <section aria-label="Responsible use" className="mx-auto max-w-[1200px] px-6 pt-16">
          <div className="flex flex-wrap items-center gap-4 rounded-2xl border border-info/25 bg-info-subtle px-6 py-5">
            <ShieldCheck className="size-6 flex-none text-info" />
            <div className="flex min-w-[240px] flex-1 flex-col gap-1">
              <b>Record responsibly</b>
              <span className="text-sm text-muted-foreground">
                Only add channels you own, manage, or have clear permission to record. We may remove
                channels that break this rule.
              </span>
            </div>
            <Link to="/acceptable-use" className="text-sm font-semibold text-accent-ink">
              Read the Acceptable Use Policy →
            </Link>
          </div>
        </section>

        <LandingFaq retention={retentionSentence(pricing)} />

        {/* Final CTA */}
        <section className="mx-auto max-w-[1200px] px-6 pt-24">
          <div className="relative overflow-hidden rounded-[28px] bg-primary px-8 py-16 text-center text-primary-foreground shadow-glow">
            <h2 className="text-[clamp(30px,3.4vw,44px)] font-extrabold tracking-[-.025em]">
              Your next LIVE is already covered.
            </h2>
            <p className="mx-auto mt-4 max-w-xl text-lg text-primary-foreground/85">
              Add your channel in under a minute.
            </p>
            <div className="mt-8 flex flex-wrap justify-center gap-3">
              <Button size="lg" variant="secondary" asChild>
                <Link to={startTo}>{authenticated ? "Open dashboard" : "Start for free"}</Link>
              </Button>
              <Button
                size="lg"
                variant="outline"
                className="border-primary-foreground/40 bg-transparent text-primary-foreground hover:bg-primary-foreground/10"
                asChild
              >
                <Link to="/pricing">See pricing</Link>
              </Button>
            </div>
            <p className="mt-4 text-sm text-primary-foreground/80">
              No payment to sign up · Credits never expire
            </p>
          </div>
        </section>
      </main>
      <PublicFooter />
    </div>
  );
}

function Feature({
  icon: Icon,
  title,
  body,
  className,
}: {
  icon: typeof Radio;
  title: string;
  body: string;
  className?: string;
}) {
  return (
    <article
      className={cn(
        card,
        "flex flex-col gap-3 p-7 transition hover:-translate-y-1 hover:border-primary/40",
        className,
      )}
    >
      <span className="grid size-10 place-items-center rounded-xl bg-primary-subtle text-accent-ink">
        <Icon className="size-5" />
      </span>
      <h3 className="text-lg font-bold">{title}</h3>
      <p className="leading-relaxed text-muted-foreground">{body}</p>
    </article>
  );
}

/** Static illustration of the dashboard (not live data). */
function HeroMockup() {
  return (
    <div className="relative" aria-hidden>
      <div className="absolute inset-[8%_6%_4%_10%] rounded-full bg-primary/30 blur-3xl" />
      <div className={cn(card, "relative overflow-hidden")}>
        <div className="flex items-center gap-2 border-b px-4 py-3 text-sm">
          <span className="font-bold">Channels</span>
          <span className="ml-auto font-mono text-xs text-muted-foreground">savestream.online</span>
        </div>
        <div className="flex flex-col gap-3 p-4">
          <div className="flex items-center gap-3 rounded-xl border bg-surface-2 p-3.5">
            <span className="grid size-10 place-items-center rounded-full bg-gradient-to-br from-avatar-one to-avatar-one-end text-xs font-bold text-avatar-foreground">
              YC
            </span>
            <span className="flex flex-col">
              <b className="text-sm">@yourchannel</b>
              <span className="text-xs text-muted-foreground">Live now · recording</span>
            </span>
            <span className="ml-auto inline-flex items-center gap-1.5 rounded-full bg-recording px-2.5 py-1 text-[11px] font-extrabold tracking-[.08em] text-white">
              <span className="size-1.5 rounded-full bg-white" />
              LIVE
            </span>
          </div>
          {["@studio.backup", "@brand.shop"].map((handle) => (
            <div key={handle} className="flex items-center gap-3 rounded-xl border p-3.5">
              <span className="grid size-10 place-items-center rounded-full bg-gradient-to-br from-avatar-two to-avatar-two-end text-xs font-bold text-avatar-foreground">
                {handle.slice(1, 3).toUpperCase()}
              </span>
              <span className="flex flex-col">
                <b className="text-sm">{handle}</b>
                <span className="text-xs text-muted-foreground">Offline · checking</span>
              </span>
              <span className="ml-auto rounded-full bg-surface-2 px-2.5 py-1 text-xs font-bold text-muted-foreground">
                Watching
              </span>
            </div>
          ))}
          <div className="flex items-center gap-3 rounded-xl border p-3.5">
            <Video className="size-5 text-accent-ink" />
            <span className="flex flex-col">
              <b className="text-sm">Recording ready</b>
              <span className="text-xs text-muted-foreground">
                Watch in the browser or download
              </span>
            </span>
            <span className="ml-auto rounded-full bg-success-subtle px-2.5 py-1 text-xs font-bold text-success">
              Ready
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

function LandingFaq({ retention }: { retention: string }) {
  const [open, setOpen] = useState(0);
  const faqs: [string, string][] = [
    [
      "Does my computer or phone need to stay on?",
      "No. Detection and recording run on SaveStream’s cloud servers. Once your channel is added you can close every device; recordings appear in your dashboard when the LIVE ends.",
    ],
    [
      "How quickly is a LIVE detected?",
      "Channels are checked about every 20 seconds, so a LIVE is usually detected within a minute of starting.",
    ],
    [
      "How do credits work? Do they expire?",
      "Credits pay for recording time and are only used while a LIVE is being recorded — checking offline channels is free. Unused credits never expire.",
    ],
    [
      "When does automatic recording start?",
      "After your first credit purchase, switch on Auto-record for a channel. From then on its LIVEs are recorded automatically.",
    ],
    ["How long are recordings kept?", `${retention}. Download anything you want to keep longer.`],
    [
      "Which channels am I allowed to record?",
      "Only channels you own, manage, or have clear permission from the creator to record. Adding a channel confirms you have that right.",
    ],
  ];
  return (
    <section id="faq" className="mx-auto max-w-[860px] scroll-mt-20 px-6 pt-24">
      <div className="mb-8 flex flex-col items-center gap-3 text-center">
        <span className={eyebrow}>FAQ</span>
        <h2 className={sectionTitle}>Questions, answered.</h2>
      </div>
      <div className="flex flex-col gap-3">
        {faqs.map(([question, answer], index) => {
          const isOpen = open === index;
          return (
            <div key={question} className="rounded-2xl border bg-surface">
              <button
                type="button"
                aria-expanded={isOpen}
                onClick={() => setOpen(isOpen ? -1 : index)}
                className="flex min-h-16 w-full items-center justify-between gap-4 px-[22px] py-[18px] text-left text-[17px] font-semibold hover:text-accent-ink"
              >
                <span>{question}</span>
                <ChevronDown
                  className={cn("size-5 flex-none transition-transform", isOpen && "rotate-180")}
                />
              </button>
              {isOpen && (
                <p className="px-[22px] pb-[22px] leading-relaxed text-muted-foreground">
                  {answer}
                </p>
              )}
            </div>
          );
        })}
      </div>
      <p className="mt-6 text-center text-sm text-muted-foreground">
        More answers in the{" "}
        <Link to="/help" className="font-semibold text-accent-ink">
          help center
        </Link>
        .
      </p>
    </section>
  );
}
