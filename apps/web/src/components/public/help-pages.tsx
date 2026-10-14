import { Link, useNavigate } from "@tanstack/react-router";
import { useMemo, useState, type MouseEvent, type ReactNode } from "react";
import {
  AlertTriangle,
  ArrowRight,
  CreditCard,
  FileVideo,
  Info,
  MessageSquare,
  Radio,
  Rocket,
  Search,
  ShieldCheck,
} from "lucide-react";
import { AppShell } from "@/components/app-components";
import { PublicFooter, PublicHeader } from "@/components/app-pages";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useAuth } from "@/auth/auth-context";
import { usePublicPricingData } from "@/hooks/use-domain-data";
import {
  articlesIn,
  helpArticle,
  helpCategories,
  helpVariables,
  renderHelpArticle,
  searchHelp,
  type HelpArticle,
  type HelpCategoryId,
} from "@/lib/help-content";
import { cn } from "@/lib/utils";

const categoryIcons: Record<HelpCategoryId, typeof Rocket> = {
  "getting-started": Rocket,
  channels: Radio,
  recordings: FileVideo,
  billing: CreditCard,
  account: ShieldCheck,
  troubleshooting: AlertTriangle,
};

const POPULAR = [
  "add-a-channel",
  "automatic-recording",
  "storage-and-downloads",
  "credits-and-pricing",
];

/** Signed-in users read help inside the app shell; guests get the public page. */
function HelpFrame({ children }: { children: ReactNode }) {
  const { status } = useAuth();
  if (status === "authenticated") return <AppShell>{children}</AppShell>;
  return (
    <div className="min-h-screen bg-background">
      <PublicHeader />
      <div className="pt-[72px]">{children}</div>
      <PublicFooter />
    </div>
  );
}

function ArticleLink({ article, className }: { article: HelpArticle; className?: string }) {
  return (
    <Link to="/help/$article" params={{ article: article.slug }} className={className}>
      {article.title}
    </Link>
  );
}

export function HelpCenterPage() {
  const [query, setQuery] = useState("");
  const results = useMemo(() => searchHelp(query), [query]);
  const popular = POPULAR.map(helpArticle).filter((item): item is HelpArticle => !!item);

  return (
    <HelpFrame>
      <section className="relative overflow-hidden border-b">
        <div aria-hidden className="hero-glow" />
        <div className="relative mx-auto flex max-w-[1200px] flex-col items-center gap-5 px-6 pb-[72px] pt-20 text-center">
          <h1 className="text-[48px] font-extrabold leading-[1.05] tracking-[-.035em]">
            How can we help?
          </h1>
          <p className="text-lg text-muted-foreground">
            Guides and answers for recording your TikTok LIVEs.
          </p>
          <form
            role="search"
            className="mt-2 w-full max-w-[640px]"
            onSubmit={(event) => event.preventDefault()}
          >
            <label className="relative block" htmlFor="help-search">
              <span className="sr-only">Search help articles</span>
              <Search className="pointer-events-none absolute left-4 top-1/2 size-5 -translate-y-1/2 text-muted-foreground" />
              <Input
                id="help-search"
                type="search"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Search articles, e.g. “recording didn’t start”"
                className="h-[60px] rounded-2xl pl-12 text-[17px] shadow-card"
              />
            </label>
          </form>
          {query.trim() ? (
            <div className="w-full max-w-[640px] text-left" aria-live="polite">
              {results.length ? (
                <ul className="divide-y rounded-2xl border bg-surface shadow-card">
                  {results.map((article) => (
                    <li key={article.slug}>
                      <Link
                        to="/help/$article"
                        params={{ article: article.slug }}
                        className="flex flex-col gap-1 px-5 py-4 hover:bg-surface-2"
                      >
                        <span className="font-semibold">{article.title}</span>
                        <span className="text-sm text-muted-foreground">{article.summary}</span>
                      </Link>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="rounded-2xl border bg-surface px-5 py-4 text-sm text-muted-foreground">
                  No articles match “{query}”. Try fewer words, or{" "}
                  <Link to="/contact" className="font-medium text-accent-ink">
                    contact support
                  </Link>
                  .
                </p>
              )}
            </div>
          ) : (
            <p className="flex flex-wrap items-center justify-center gap-2 text-sm">
              <span className="text-muted-foreground">Popular:</span>
              {popular.map((article, index) => (
                <span key={article.slug} className="flex items-center gap-2">
                  {index > 0 && <span className="text-muted-foreground">·</span>}
                  <ArticleLink article={article} className="font-medium text-accent-ink" />
                </span>
              ))}
            </p>
          )}
        </div>
      </section>

      <section className="mx-auto max-w-[1200px] px-6 pt-16" aria-labelledby="help-topics">
        <h2 id="help-topics" className="mb-6 text-[21px] font-bold tracking-[-.015em]">
          Browse by topic
        </h2>
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {helpCategories.map((category) => {
            const Icon = categoryIcons[category.id];
            const articles = articlesIn(category.id);
            const first = articles[0];
            return (
              <div
                key={category.id}
                className="flex flex-col gap-3.5 rounded-2xl border bg-surface p-6 shadow-card transition hover:-translate-y-0.5 hover:border-primary/40"
              >
                <div className="flex items-center">
                  <span className="grid size-10 place-items-center rounded-xl bg-primary-subtle text-accent-ink">
                    <Icon className="size-5" />
                  </span>
                  <span className="ml-auto text-xs text-muted-foreground">
                    {articles.length} {articles.length === 1 ? "article" : "articles"}
                  </span>
                </div>
                <div className="flex flex-col gap-1">
                  <h3 className="text-lg font-bold">
                    {first ? (
                      <Link to="/help/$article" params={{ article: first.slug }}>
                        {category.title}
                      </Link>
                    ) : (
                      category.title
                    )}
                  </h3>
                  <p className="text-sm text-muted-foreground">{category.description}</p>
                </div>
                <ul className="flex flex-col gap-2 border-t pt-3 text-sm font-medium">
                  {articles.slice(0, 4).map((article) => (
                    <li key={article.slug}>
                      <ArticleLink article={article} className="text-accent-ink hover:underline" />
                    </li>
                  ))}
                </ul>
              </div>
            );
          })}
        </div>
      </section>

      <section className="mx-auto max-w-[1200px] px-6 pb-4 pt-12">
        <StillStuck />
      </section>
    </HelpFrame>
  );
}

function StillStuck() {
  return (
    <div className="flex flex-wrap items-center gap-5 rounded-2xl border bg-gradient-to-br from-primary-subtle to-surface p-8 shadow-card">
      <span className="grid size-[52px] place-items-center rounded-2xl bg-primary text-primary-foreground">
        <MessageSquare className="size-6" />
      </span>
      <div className="flex min-w-[220px] flex-1 flex-col gap-1">
        <b className="text-lg">Still stuck?</b>
        <span className="text-muted-foreground">
          Email us and include your channel name and the time of the LIVE. We usually reply within
          [RESPONSE TIME].
        </span>
      </div>
      <Button variant="outline" asChild>
        <Link to="/status">System status</Link>
      </Button>
      <Button asChild>
        <Link to="/contact">Contact support</Link>
      </Button>
    </div>
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

export function HelpArticlePage({ slug }: { slug: string }) {
  const navigate = useNavigate();
  const { query: pricingQuery } = usePublicPricingData();
  const article = helpArticle(slug);
  const rendered = useMemo(
    () => (article ? renderHelpArticle(article, helpVariables(pricingQuery.data)) : null),
    [article, pricingQuery.data],
  );

  if (!article || !rendered) {
    return (
      <HelpFrame>
        <main className="mx-auto flex max-w-xl flex-col items-center gap-4 px-6 py-24 text-center">
          <h1 className="text-[28px] font-extrabold">Article not found</h1>
          <p className="text-muted-foreground">
            This help article may have moved. Browse the help center instead.
          </p>
          <Button asChild>
            <Link to="/help">Go to the help center</Link>
          </Button>
        </main>
      </HelpFrame>
    );
  }

  const category = helpCategories.find((item) => item.id === article.category)!;
  const siblings = articlesIn(article.category);
  const related = [
    ...siblings.filter((item) => item.slug !== article.slug),
    ...articlesIn("troubleshooting").filter((item) => item.slug !== article.slug),
  ].slice(0, 3);

  // Links inside the Markdown are plain <a>; keep in-app ones in the router.
  const onProseClick = (event: MouseEvent<HTMLDivElement>) => {
    const anchor = (event.target as HTMLElement).closest("a");
    const href = anchor?.getAttribute("href");
    if (!anchor || !href || !href.startsWith("/") || event.metaKey || event.ctrlKey) return;
    event.preventDefault();
    void navigate({ to: href });
  };

  return (
    <HelpFrame>
      <div className="mx-auto flex max-w-[1240px] flex-wrap items-start gap-12 px-6 pt-8">
        <aside
          className="hidden w-60 flex-none flex-col gap-1 lg:flex"
          aria-label={`${category.title} articles`}
        >
          <span className="px-3 pb-2.5 text-xs font-bold uppercase tracking-[.08em] text-accent-ink">
            {category.title}
          </span>
          {siblings.map((item) => (
            <Link
              key={item.slug}
              to="/help/$article"
              params={{ article: item.slug }}
              aria-current={item.slug === article.slug ? "page" : undefined}
              className={cn(
                "flex min-h-10 items-center rounded-[10px] px-3 text-sm font-semibold text-muted-foreground hover:bg-surface-2 hover:text-foreground",
                item.slug === article.slug && "bg-primary-subtle text-accent-ink",
              )}
            >
              {item.title}
            </Link>
          ))}
        </aside>

        <article className="min-w-0 max-w-[720px] flex-[999_1_560px]">
          <nav aria-label="Breadcrumb" className="mb-5 flex gap-2 text-sm text-muted-foreground">
            <Link to="/help" className="hover:text-foreground">
              Help center
            </Link>
            <span aria-hidden>/</span>
            <span>{category.title}</span>
          </nav>
          <h1 className="text-[42px] font-extrabold leading-[1.08] tracking-[-.035em]">
            {article.title}
          </h1>
          <div className="mb-7 mt-4 flex gap-3.5 text-sm text-muted-foreground">
            {article.updated && <span>Updated {formatUpdated(article.updated)}</span>}
            <span aria-hidden>·</span>
            <span>{rendered.minutes} min read</span>
          </div>
          {article.summary && (
            <div className="mb-7 flex items-start gap-3 rounded-[14px] border border-info/25 bg-info-subtle px-[18px] py-3.5 text-sm">
              <Info className="mt-0.5 size-5 flex-none text-info" />
              <span>{article.summary}</span>
            </div>
          )}
          <div
            className="help-prose"
            onClick={onProseClick}
            // Repository-authored Markdown; placeholders are HTML-escaped.
            dangerouslySetInnerHTML={{ __html: rendered.html }}
          />
          <h2 className="mb-4 mt-10 text-[21px] font-bold">Related articles</h2>
          <div className="grid gap-3 sm:grid-cols-3">
            {related.map((item) => (
              <Link
                key={item.slug}
                to="/help/$article"
                params={{ article: item.slug }}
                className="flex flex-col gap-1 rounded-2xl border bg-surface p-4 transition hover:-translate-y-0.5 hover:border-primary/40"
              >
                <b className="text-sm">{item.title}</b>
                <span className="text-xs text-muted-foreground">
                  {helpCategories.find((c) => c.id === item.category)?.title}
                </span>
              </Link>
            ))}
          </div>
          <div className="mt-10">
            <StillStuck />
          </div>
        </article>

        {rendered.headings.length > 1 && (
          <nav
            aria-label="On this page"
            className="sticky top-24 hidden w-[200px] flex-none flex-col gap-2.5 text-sm xl:flex"
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
    </HelpFrame>
  );
}

export function HelpArticleLinkCard({ slug }: { slug: string }) {
  const article = helpArticle(slug);
  if (!article) return null;
  return (
    <Link
      to="/help/$article"
      params={{ article: slug }}
      className="flex items-center gap-3 rounded-2xl border bg-surface p-4 hover:border-primary/40"
    >
      <span className="flex-1 text-sm font-semibold">{article.title}</span>
      <ArrowRight className="size-4 text-muted-foreground" />
    </Link>
  );
}
