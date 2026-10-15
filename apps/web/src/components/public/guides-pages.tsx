import { Link, useNavigate } from "@tanstack/react-router";
import { useMemo, type MouseEvent, type ReactNode } from "react";
import { ArrowRight, BookOpen, Info, ShieldCheck } from "lucide-react";
import { PublicFooter, PublicHeader } from "@/components/app-pages";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/auth/auth-context";
import { usePublicPricingData } from "@/hooks/use-domain-data";
import { guide, guides, guideStructuredData, type Guide } from "@/lib/guides-content";
import { helpVariables, renderHelpArticle } from "@/lib/help-content";

/** Guides are public marketing pages: same frame for guests and signed-in users. */
export function PublicFrame({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <div className="pt-[72px]">{children}</div>
      <PublicFooter />
    </div>
  );
}

export function JsonLd({ data }: { data: unknown }) {
  return (
    <script
      type="application/ld+json"
      // Built from repository content; "<" is escaped so it can't close the tag.
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data).replace(/</g, "\\u003c") }}
    />
  );
}

function formatUpdated(value: string) {
  const date = new Date(`${value}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC",
  }).format(date);
}

function readMinutes(item: Guide) {
  return Math.max(1, Math.round(item.body.split(/\s+/).length / 200));
}

/** Sign-up call to action with the permission rule from the Acceptable Use Policy. */
export function StartRecordingCta({
  title = "Record your own LIVEs automatically",
}: {
  title?: string;
}) {
  const { status } = useAuth();
  const authenticated = status === "authenticated";
  return (
    <div className="flex flex-col gap-5 rounded-2xl border bg-gradient-to-br from-primary-subtle to-surface p-8 shadow-card">
      <div className="flex flex-col gap-2">
        <b className="text-[21px] font-bold tracking-[-.015em]">{title}</b>
        <p className="text-muted-foreground">
          SaveStream watches the TikTok channels you add and records their LIVEs in the cloud, so
          nothing has to stay open on your phone or computer.
        </p>
      </div>
      <div className="flex flex-wrap gap-3">
        <Button asChild>
          <Link to={authenticated ? "/overview" : "/sign-up"}>
            {authenticated ? "Open SaveStream" : "Create a free account"}
          </Link>
        </Button>
        <Button variant="outline" asChild>
          <Link to="/tiktok-live-recorder">How the recorder works</Link>
        </Button>
      </div>
      <p className="flex items-start gap-2 text-sm text-muted-foreground">
        <ShieldCheck className="mt-0.5 size-4 flex-none text-info" />
        <span>
          Only add channels you own, manage, or have clear permission to record. See the{" "}
          <Link to="/acceptable-use" className="font-semibold text-accent-ink">
            Acceptable Use Policy
          </Link>
          .
        </span>
      </p>
    </div>
  );
}

function GuideCard({ item }: { item: Guide }) {
  return (
    <Link
      to="/guides/$guide"
      params={{ guide: item.slug }}
      className="flex flex-col gap-3 rounded-2xl border bg-surface p-6 shadow-card transition hover:-translate-y-0.5 hover:border-primary/40"
    >
      <span className="grid size-10 place-items-center rounded-xl bg-primary-subtle text-accent-ink">
        <BookOpen className="size-5" />
      </span>
      <h2 className="text-lg font-bold leading-snug">{item.title}</h2>
      <p className="flex-1 text-sm leading-6 text-muted-foreground">{item.summary}</p>
      <span className="flex items-center gap-1.5 text-sm font-semibold text-accent-ink">
        Read guide · {readMinutes(item)} min
        <ArrowRight className="size-4" />
      </span>
    </Link>
  );
}

export function GuidesIndexPage() {
  return (
    <PublicFrame>
      <section className="relative overflow-hidden border-b">
        <div aria-hidden className="hero-glow" />
        <div className="relative mx-auto flex max-w-[1200px] flex-col items-center gap-4 px-6 pb-16 pt-20 text-center">
          <span className="text-[13px] font-bold uppercase tracking-[.08em] text-accent-ink">
            Guides
          </span>
          <h1 className="max-w-3xl text-[clamp(36px,4.4vw,52px)] font-extrabold leading-[1.06] tracking-[-.035em] text-balance">
            Recording and reusing your TikTok LIVEs
          </h1>
          <p className="max-w-2xl text-lg leading-relaxed text-muted-foreground">
            Practical guides for creators and sellers: manual methods, automatic cloud recording,
            saving replays and turning streams into clips.
          </p>
        </div>
      </section>
      <section className="mx-auto max-w-[1200px] px-6 pt-14" aria-label="All guides">
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {guides.map((item) => (
            <GuideCard key={item.slug} item={item} />
          ))}
        </div>
        <p className="mt-8 text-sm text-muted-foreground">
          Looking for help with your account? Visit the{" "}
          <Link to="/help" className="font-semibold text-accent-ink">
            help center
          </Link>
          .
        </p>
      </section>
      <section className="mx-auto max-w-[1200px] px-6 pt-12">
        <StartRecordingCta />
      </section>
    </PublicFrame>
  );
}

export function GuidePage({ slug }: { slug: string }) {
  const navigate = useNavigate();
  const { query: pricingQuery } = usePublicPricingData();
  const item = guide(slug);
  const vars = useMemo(() => helpVariables(pricingQuery.data), [pricingQuery.data]);
  const rendered = useMemo(() => (item ? renderHelpArticle(item, vars) : null), [item, vars]);
  const structured = useMemo(() => (item ? guideStructuredData(item, vars) : null), [item, vars]);

  if (!item || !rendered) {
    return (
      <PublicFrame>
        <main className="mx-auto flex max-w-xl flex-col items-center gap-4 px-6 py-24 text-center">
          <h1 className="text-[28px] font-extrabold">Guide not found</h1>
          <p className="text-muted-foreground">
            This guide may have moved. See all guides instead.
          </p>
          <Button asChild>
            <Link to="/guides">All guides</Link>
          </Button>
        </main>
      </PublicFrame>
    );
  }

  const more = guides.filter((other) => other.slug !== item.slug).slice(0, 3);

  // Links inside the Markdown are plain <a>; keep in-app ones in the router.
  const onProseClick = (event: MouseEvent<HTMLDivElement>) => {
    const anchor = (event.target as HTMLElement).closest("a");
    const href = anchor?.getAttribute("href");
    if (!anchor || !href || !href.startsWith("/") || event.metaKey || event.ctrlKey) return;
    event.preventDefault();
    void navigate({ to: href });
  };

  return (
    <PublicFrame>
      <JsonLd data={structured} />
      <div className="mx-auto flex max-w-[1100px] flex-wrap items-start gap-12 px-6 pt-8">
        <article className="min-w-0 max-w-[740px] flex-[999_1_560px]">
          <nav aria-label="Breadcrumb" className="mb-5 flex gap-2 text-sm text-muted-foreground">
            <Link to="/guides" className="hover:text-foreground">
              Guides
            </Link>
            <span aria-hidden>/</span>
            <span className="truncate">{item.title}</span>
          </nav>
          <h1 className="text-[clamp(32px,4vw,44px)] font-extrabold leading-[1.08] tracking-[-.035em] text-balance">
            {item.title}
          </h1>
          <div className="mb-7 mt-4 flex gap-3.5 text-sm text-muted-foreground">
            {item.updated && <span>Updated {formatUpdated(item.updated)}</span>}
            <span aria-hidden>·</span>
            <span>{rendered.minutes} min read</span>
          </div>
          {item.summary && (
            <div className="mb-7 flex items-start gap-3 rounded-[14px] border border-info/25 bg-info-subtle px-[18px] py-3.5 text-sm">
              <Info className="mt-0.5 size-5 flex-none text-info" />
              <span>{item.summary}</span>
            </div>
          )}
          <div
            className="help-prose"
            onClick={onProseClick}
            // Repository-authored Markdown; placeholders are HTML-escaped.
            dangerouslySetInnerHTML={{ __html: rendered.html }}
          />
          <div className="mt-10">
            <StartRecordingCta />
          </div>
          <h2 className="mb-4 mt-12 text-[21px] font-bold">More guides</h2>
          <div className="grid gap-3 sm:grid-cols-3">
            {more.map((other) => (
              <Link
                key={other.slug}
                to="/guides/$guide"
                params={{ guide: other.slug }}
                className="flex flex-col gap-1 rounded-2xl border bg-surface p-4 transition hover:-translate-y-0.5 hover:border-primary/40"
              >
                <b className="text-sm">{other.title}</b>
                <span className="text-xs text-muted-foreground">{readMinutes(other)} min read</span>
              </Link>
            ))}
          </div>
        </article>

        {rendered.headings.length > 1 && (
          <nav
            aria-label="On this page"
            className="sticky top-24 hidden w-[220px] flex-none flex-col gap-2.5 text-sm lg:flex"
          >
            <b className="text-sm">On this page</b>
            {rendered.headings.map((heading) => (
              <a
                key={heading.id}
                href={`#${heading.id}`}
                className="border-l-2 border-border pl-2.5 text-muted-foreground hover:border-primary hover:text-accent-ink"
              >
                {heading.text}
              </a>
            ))}
          </nav>
        )}
      </div>
    </PublicFrame>
  );
}
