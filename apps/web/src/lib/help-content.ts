import { marked, type Tokens } from "marked";
import { SUPPORT_EMAIL, SUPPORT_RESPONSE_TIME } from "@/lib/support";
import type { PublicPricingResponse } from "@/api/types";
import { pluralize } from "@/lib/formatters";

/**
 * Help center articles live as Markdown files in `src/content/help/*.md`, so
 * they can be edited without touching components. Each file starts with a
 * frontmatter block:
 *
 *   ---
 *   title: Add a channel
 *   category: channels            # one of helpCategories[].id
 *   summary: One sentence for the article list and the meta description.
 *   updated: 2026-10-14
 *   order: 2                      # position inside the category
 *   ---
 *
 * The body is Markdown. `{{token}}` placeholders are filled from the live
 * Admin runtime settings (see helpVariables) so numbers such as trial credits
 * or retention days never go stale; unknown values fall back to wording
 * without a number. Bracketed ALL-CAPS placeholders are not allowed: the
 * public-placeholder audit fails the build if one reaches a page.
 */

export type HelpCategoryId =
  "getting-started" | "channels" | "recordings" | "billing" | "account" | "troubleshooting";

export type HelpCategory = {
  id: HelpCategoryId;
  title: string;
  description: string;
};

export const helpCategories: readonly HelpCategory[] = [
  {
    id: "getting-started",
    title: "Getting started",
    description: "Create an account, add a channel and record your first LIVE.",
  },
  {
    id: "channels",
    title: "Channels & detection",
    description: "Adding channels, automatic recording, pausing and limits.",
  },
  {
    id: "recordings",
    title: "Recordings & playback",
    description: "Watching, downloading, storage and retention.",
  },
  {
    id: "billing",
    title: "Credits & billing",
    description: "Credits, packs, PayPal payments, receipts and refunds.",
  },
  {
    id: "account",
    title: "Account & security",
    description: "Sign-in, password, sessions and your data.",
  },
  {
    id: "troubleshooting",
    title: "Troubleshooting",
    description: "Fixes for missed LIVEs and failed recordings.",
  },
];

export type HelpArticle = {
  slug: string;
  title: string;
  category: HelpCategoryId;
  summary: string;
  updated: string;
  order: number;
  body: string;
};

const sources = import.meta.glob("/src/content/help/*.md", {
  query: "?raw",
  import: "default",
  eager: true,
}) as Record<string, string>;

function parseArticle(path: string, raw: string): HelpArticle {
  const slug = path.split("/").pop()!.replace(/\.md$/, "");
  const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/.exec(raw);
  if (!match) throw new Error(`Help article ${slug} has no frontmatter`);
  const fields: Record<string, string> = {};
  for (const line of match[1]!.split(/\r?\n/)) {
    const pair = /^([a-z_]+):\s*(.*)$/.exec(line.trim());
    if (pair) fields[pair[1]!] = pair[2]!.replace(/\s+#.*$/, "").trim();
  }
  const category = fields["category"] as HelpCategoryId;
  if (!helpCategories.some((item) => item.id === category)) {
    throw new Error(`Help article ${slug} has an unknown category "${category}"`);
  }
  return {
    slug,
    title: fields["title"] ?? slug,
    category,
    summary: fields["summary"] ?? "",
    updated: fields["updated"] ?? "",
    order: Number(fields["order"] ?? 99),
    body: match[2]!.trim(),
  };
}

export const helpArticles: readonly HelpArticle[] = Object.entries(sources)
  .map(([path, raw]) => parseArticle(path, raw))
  .sort((a, b) => a.order - b.order || a.title.localeCompare(b.title));

export function helpArticle(slug: string): HelpArticle | undefined {
  return helpArticles.find((article) => article.slug === slug);
}

export function articlesIn(category: HelpCategoryId): HelpArticle[] {
  return helpArticles.filter((article) => article.category === category);
}

export function searchHelp(query: string): HelpArticle[] {
  const words = query.toLowerCase().split(/\s+/).filter(Boolean);
  if (!words.length) return [];
  return helpArticles.filter((article) => {
    const text = `${article.title} ${article.summary} ${article.body}`.toLowerCase();
    return words.every((word) => text.includes(word));
  });
}

/** Values for `{{token}}` placeholders, from the public pricing settings. */
export function helpVariables(pricing: PublicPricingResponse | null | undefined) {
  const rate = pricing?.recording_rate;
  const minutesPerCredit =
    rate && rate.credits_per_unit > 0 ? rate.unit_seconds / 60 / rate.credits_per_unit : null;
  const days = (value: number | null | undefined, fallback: string) =>
    value ? pluralize(value, "day") : fallback;
  return {
    signup_credits: pricing?.signup_credits
      ? pluralize(pricing.signup_credits, "free trial credit")
      : "free trial credits",
    free_channels: pricing?.free_max_channels_per_user
      ? `up to ${pluralize(pricing.free_max_channels_per_user, "channel")}`
      : "a limited number of channels",
    pro_channels: pricing?.max_channels_per_user
      ? `up to ${pluralize(pricing.max_channels_per_user, "channel")}`
      : "more channels",
    parallel_recordings: pricing?.max_concurrent_recordings_per_user
      ? pluralize(pricing.max_concurrent_recordings_per_user, "livestream")
      : "several livestreams",
    paid_retention: days(pricing?.recording_retention_days, "a limited time"),
    trial_retention: days(
      pricing?.trial_recording_retention_days ?? pricing?.recording_retention_days,
      "a shorter time",
    ),
    credit_rate:
      minutesPerCredit === null
        ? "the rate shown on the Pricing page"
        : minutesPerCredit === 1
          ? "1 credit per minute of recording"
          : `1 credit per ${minutesPerCredit} minutes of recording`,
    minimum_credits:
      rate && rate.minimum_credits > 0
        ? `a minimum of ${pluralize(rate.minimum_credits, "credit")} per recording`
        : "no minimum charge",
    support_email: SUPPORT_EMAIL,
    support_response_time: SUPPORT_RESPONSE_TIME,
  } satisfies Record<string, string>;
}

export type HelpVariables = ReturnType<typeof helpVariables>;

function slugify(text: string) {
  return text
    .toLowerCase()
    .replace(/<[^>]+>/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function escapeHtml(value: string) {
  return value.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

/** Markdown body to HTML, with heading anchors for the "On this page" list. */
export function renderHelpArticle(article: HelpArticle, vars: HelpVariables) {
  const filled = article.body.replace(/\{\{\s*([a-z_]+)\s*\}\}/g, (token, key: string) =>
    key in vars ? escapeHtml(vars[key as keyof HelpVariables]) : token,
  );
  const headings: { id: string; text: string }[] = [];
  const renderer = new marked.Renderer();
  renderer.heading = function ({ tokens, depth }: Tokens.Heading) {
    const inner = this.parser.parseInline(tokens);
    const id = slugify(inner);
    if (depth === 2) headings.push({ id, text: inner.replace(/<[^>]+>/g, "") });
    return `<h${depth} id="${id}">${inner}</h${depth}>`;
  };
  const html = marked.parse(filled, { renderer, async: false, gfm: true }) as string;
  const words = article.body.split(/\s+/).length;
  return { html, headings, minutes: Math.max(1, Math.round(words / 200)) };
}
