import { Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { CheckCircle2, Clock3, HelpCircle, Mail, RefreshCw, XCircle } from "lucide-react";
import { PublicFooter, PublicHeader } from "@/components/app-pages";
import { Button } from "@/components/ui/button";
import { fetchReadiness } from "@/api/health";
import { cn } from "@/lib/utils";

const card = "rounded-2xl border bg-surface";

export type ContactChannel = { title: string; email: string; body: string };

/** Public contact page (design "Contact"): email channels, no web form yet. */
export function PublicContactPage({ contacts }: { contacts: ContactChannel[] }) {
  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <main className="relative pt-[72px]">
        <div aria-hidden className="hero-glow" />
        <div className="relative mx-auto grid max-w-[1200px] items-start gap-14 px-6 pt-[72px] lg:grid-cols-2">
          <div className="flex flex-col gap-5">
            <span className="text-xs font-bold uppercase tracking-[.08em] text-accent-ink">
              Contact
            </span>
            <h1 className="text-[48px] font-extrabold leading-[1.05] tracking-[-.035em]">
              Contact us
            </h1>
            <p className="text-lg leading-relaxed text-muted-foreground">
              Questions about a recording, a payment or your account? Email us and we will get back
              to you.
            </p>
            <div className="mt-3 flex flex-col gap-3">
              <div className={cn(card, "flex items-center gap-3.5 p-4")}>
                <span className="grid size-10 flex-none place-items-center rounded-xl bg-primary-subtle text-accent-ink">
                  <Mail className="size-5" />
                </span>
                <div className="flex flex-col">
                  <b className="text-sm">Email</b>
                  <a href="mailto:support@savestream.online" className="text-sm text-accent-ink">
                    support@savestream.online
                  </a>
                </div>
              </div>
              <div className={cn(card, "flex items-center gap-3.5 p-4")}>
                <span className="grid size-10 flex-none place-items-center rounded-xl bg-success-subtle text-success">
                  <Clock3 className="size-5" />
                </span>
                <div className="flex flex-col">
                  <b className="text-sm">Response time</b>
                  <span className="text-sm text-muted-foreground">
                    Usually within [RESPONSE TIME]
                  </span>
                </div>
              </div>
              <Link
                to="/help"
                className={cn(
                  card,
                  "flex items-center gap-3.5 p-4 transition hover:-translate-y-0.5 hover:border-primary/40",
                )}
              >
                <span className="grid size-10 flex-none place-items-center rounded-xl bg-info-subtle text-info">
                  <HelpCircle className="size-5" />
                </span>
                <div className="flex flex-1 flex-col">
                  <b className="text-sm">Help center</b>
                  <span className="text-sm text-muted-foreground">
                    Most answers are already here
                  </span>
                </div>
                <span aria-hidden className="text-muted-foreground">
                  →
                </span>
              </Link>
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            {contacts.map((item) => (
              <section key={item.title} className={cn(card, "flex flex-col gap-2 p-6 shadow-card")}>
                <h2 className="font-bold">{item.title}</h2>
                <p className="text-sm leading-6 text-muted-foreground">{item.body}</p>
                <a
                  href={`mailto:${item.email}`}
                  className="mt-auto pt-2 text-sm font-semibold text-accent-ink"
                >
                  {item.email}
                </a>
              </section>
            ))}
          </div>
        </div>
      </main>
      <PublicFooter />
    </div>
  );
}

const componentLabels: Record<string, [string, string]> = {
  postgres: ["Accounts & data", "Sign-in, channels and recordings list"],
  redis: ["Job queue", "Live checks and recording jobs"],
  minio: ["Recording storage", "Playback and downloads"],
};

/**
 * Public status page. It shows a real check of the SaveStream API made from
 * the visitor's browser (`/health/ready`), not an uptime history: SaveStream
 * does not currently publish a public live incident feed and does not display
 * illustrative service health.
 */
export function PublicStatusPage() {
  const query = useQuery({
    queryKey: ["public-status"],
    queryFn: fetchReadiness,
    refetchInterval: 60_000,
    retry: false,
  });
  const data = query.data;
  const checkedAt = query.dataUpdatedAt ? new Date(query.dataUpdatedAt) : null;
  const allOk = data?.status === "ok";
  const unreachable = query.isFetched && data === null;
  const services: [string, string, boolean | null][] = [
    ["API", "Dashboard and app requests", query.isFetched ? data !== null : null],
    ...Object.entries(componentLabels).map(
      ([key, [label, description]]): [string, string, boolean | null] => [
        label,
        description,
        data ? data.components[key]?.status === "ok" : unreachable ? false : null,
      ],
    ),
  ];

  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <main className="mx-auto flex max-w-[960px] flex-col gap-8 px-6 pt-[120px]">
        <div>
          <h1 className="text-[40px] font-extrabold tracking-[-.03em]">System status</h1>
          <p className="mt-2 text-muted-foreground">
            A live check of SaveStream services, made from your browser when you open this page.
          </p>
        </div>
        <div
          className={cn(
            "flex flex-wrap items-center gap-4 rounded-[18px] border px-7 py-6",
            query.isLoading
              ? "bg-surface"
              : allOk
                ? "border-success/25 bg-success-subtle"
                : "border-destructive/25 bg-destructive/10",
          )}
          aria-live="polite"
        >
          <span
            className={cn(
              "grid size-12 place-items-center rounded-[14px] text-white",
              query.isLoading ? "bg-muted-foreground" : allOk ? "bg-success" : "bg-destructive",
            )}
          >
            {allOk || query.isLoading ? (
              <CheckCircle2 className="size-6" />
            ) : (
              <XCircle className="size-6" />
            )}
          </span>
          <div className="flex flex-1 flex-col gap-1">
            <b className="text-[22px] tracking-[-.01em]">
              {query.isLoading
                ? "Checking services…"
                : allOk
                  ? "All checked services are operational"
                  : unreachable
                    ? "SaveStream can’t be reached from your browser"
                    : "Some services report a problem"}
            </b>
            {checkedAt && (
              <span className="text-sm text-muted-foreground">
                Last checked {checkedAt.toLocaleString("en-US", { timeZone: "UTC" })} UTC ·
                refreshes every 60 s
              </span>
            )}
          </div>
          <Button variant="outline" size="sm" onClick={() => void query.refetch()}>
            <RefreshCw />
            Check again
          </Button>
        </div>

        <section className={cn(card, "shadow-card")} aria-labelledby="status-services">
          <div className="flex items-center justify-between border-b px-6 py-4">
            <h2 id="status-services" className="font-bold">
              Services
            </h2>
            <span className="text-sm text-muted-foreground">Current check</span>
          </div>
          {services.map(([name, description, ok]) => (
            <div key={name} className="flex items-center gap-3 border-b px-6 py-4 last:border-0">
              <div className="flex flex-col">
                <b>{name}</b>
                <span className="text-xs text-muted-foreground">{description}</span>
              </div>
              <span
                className={cn(
                  "ml-auto inline-flex h-6 items-center gap-1.5 rounded-full px-2.5 text-xs font-bold",
                  ok === null
                    ? "bg-surface-2 text-muted-foreground"
                    : ok
                      ? "bg-success-subtle text-success"
                      : "bg-destructive/10 text-destructive",
                )}
              >
                <span className="size-1.5 rounded-full bg-current" />
                {ok === null ? "Checking" : ok ? "Operational" : "Problem"}
              </span>
            </div>
          ))}
        </section>

        <section className={cn(card, "p-6")}>
          <h2 className="font-bold">Incidents and history</h2>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            SaveStream does not currently publish a public live incident feed and does not display
            illustrative service health on the production site. Live detection and recording workers
            are not part of this check. If something looks wrong with a recording, email{" "}
            <a href="mailto:support@savestream.online" className="font-semibold text-accent-ink">
              support@savestream.online
            </a>
            .
          </p>
        </section>
      </main>
      <PublicFooter />
    </div>
  );
}

/** 404 for any unknown route (design "Not found"). */
export function PublicNotFoundPage() {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <PublicHeader />
      <main className="relative flex flex-1 flex-col items-center justify-center gap-5 overflow-hidden px-6 pb-24 pt-[168px] text-center">
        <div aria-hidden className="hero-glow" />
        <div aria-hidden className="relative mb-2 flex items-center gap-4">
          <span className="text-[140px] font-extrabold leading-none tracking-[-.06em] text-primary">
            4
          </span>
          <span className="grid size-[116px] place-items-center rounded-full border bg-surface shadow-card">
            <span className="size-8 rounded-full border-4 border-muted-foreground/40" />
          </span>
          <span className="text-[140px] font-extrabold leading-none tracking-[-.06em] text-primary">
            4
          </span>
        </div>
        <span className="relative inline-flex h-7 items-center gap-1.5 rounded-full bg-surface-2 px-3 text-xs font-bold text-muted-foreground">
          <span className="size-1.5 rounded-full bg-current" />
          Offline
        </span>
        <h1 className="relative text-4xl font-extrabold tracking-[-.025em]">
          This page isn’t live.
        </h1>
        <p className="relative max-w-[460px] text-lg text-muted-foreground">
          The link may be old or mistyped. Your recordings are safe — let’s get you back.
        </p>
        <div className="relative mt-2 flex flex-wrap justify-center gap-3">
          <Button size="lg" asChild>
            <Link to="/overview">Go to dashboard</Link>
          </Button>
          <Button size="lg" variant="outline" asChild>
            <Link to="/">Back to home</Link>
          </Button>
        </div>
        <p className="relative mt-3 text-sm text-muted-foreground">
          Looking for something specific?{" "}
          <Link to="/help" className="font-semibold text-accent-ink">
            Search the help center
          </Link>{" "}
          ·{" "}
          <Link to="/status" className="font-semibold text-accent-ink">
            Check status
          </Link>
        </p>
      </main>
      <PublicFooter />
    </div>
  );
}
