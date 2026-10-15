import { fillHelpTokens, type HelpVariables } from "@/lib/help-content";
import { PUBLIC_SITE_URL } from "@/lib/route-metadata";

/**
 * Guides are longer, search-friendly articles in `src/content/guides/*.md`.
 * Frontmatter:
 *
 *   ---
 *   title: How to record a TikTok LIVE
 *   summary: One or two sentences; also the meta description (≤ 160 chars).
 *   updated: 2026-10-15
 *   order: 1
 *   howto: true        # optional: the "## Step by step" list becomes HowTo data
 *   ---
 *
 * The body is Markdown with the same `{{token}}` placeholders as help
 * articles. A "## Frequently asked questions" section made of `### Question`
 * headings followed by answer paragraphs is published as FAQPage data.
 */

export type Guide = {
  slug: string;
  title: string;
  summary: string;
  updated: string;
  order: number;
  howto: boolean;
  body: string;
};

const sources = import.meta.glob("/src/content/guides/*.md", {
  query: "?raw",
  import: "default",
  eager: true,
}) as Record<string, string>;

function parseGuide(path: string, raw: string): Guide {
  const slug = path.split("/").pop()!.replace(/\.md$/, "");
  const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/.exec(raw);
  if (!match) throw new Error(`Guide ${slug} has no frontmatter`);
  const fields: Record<string, string> = {};
  for (const line of match[1]!.split(/\r?\n/)) {
    const pair = /^([a-z_]+):\s*(.*)$/.exec(line.trim());
    if (pair) fields[pair[1]!] = pair[2]!.replace(/\s+#.*$/, "").trim();
  }
  return {
    slug,
    title: fields["title"] ?? slug,
    summary: fields["summary"] ?? "",
    updated: fields["updated"] ?? "",
    order: Number(fields["order"] ?? 99),
    howto: fields["howto"] === "true",
    body: match[2]!.trim(),
  };
}

export const guides: readonly Guide[] = Object.entries(sources)
  .map(([path, raw]) => parseGuide(path, raw))
  .sort((a, b) => a.order - b.order || a.title.localeCompare(b.title));

export function guide(slug: string): Guide | undefined {
  return guides.find((item) => item.slug === slug);
}

/** Markdown to plain text for structured data (links keep their label). */
function plain(markdown: string) {
  return markdown
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/[*_`]/g, "")
    .replace(/&#(\d+);/g, (_, code: string) => String.fromCharCode(Number(code)))
    .replace(/\s+/g, " ")
    .trim();
}

/** The `##` section with this heading, without the heading line. */
function section(body: string, heading: RegExp) {
  const parts = body.split(/^## /m);
  const found = parts.find((part) => heading.test(part.split("\n")[0] ?? ""));
  return found ? found.slice(found.indexOf("\n") + 1) : "";
}

export function guideFaq(body: string): { question: string; answer: string }[] {
  const faq = section(body, /^Frequently asked questions/i);
  return faq
    .split(/^### /m)
    .slice(1)
    .map((block) => {
      const [first, ...rest] = block.split("\n");
      return { question: plain(first ?? ""), answer: plain(rest.join(" ")) };
    })
    .filter((item) => item.question && item.answer);
}

export function guideSteps(body: string): { name: string; text: string }[] {
  const steps = section(body, /^Step by step/i);
  return steps
    .split("\n")
    .filter((line) => /^\d+\.\s/.test(line))
    .map((line) => {
      const text = line.replace(/^\d+\.\s+/, "");
      const named = /^\*\*(.+?)\*\*\s*(.*)$/.exec(text);
      return named
        ? { name: plain(named[1]!).replace(/\.$/, ""), text: plain(named[2]!) || plain(named[1]!) }
        : { name: plain(text).slice(0, 80), text: plain(text) };
    });
}

const organization = {
  "@type": "Organization",
  name: "SaveStream",
  url: PUBLIC_SITE_URL,
  logo: `${PUBLIC_SITE_URL}/icon-512.png`,
};

export function faqPageData(faq: { question: string; answer: string }[]) {
  return {
    "@type": "FAQPage",
    mainEntity: faq.map((item) => ({
      "@type": "Question",
      name: item.question,
      acceptedAnswer: { "@type": "Answer", text: item.answer },
    })),
  };
}

/** JSON-LD for a guide: Article, plus HowTo and FAQPage when present. */
export function guideStructuredData(item: Guide, vars: HelpVariables) {
  const body = fillHelpTokens(item.body, vars);
  const url = `${PUBLIC_SITE_URL}/guides/${item.slug}`;
  const graph: Record<string, unknown>[] = [
    {
      "@type": "Article",
      headline: item.title,
      description: item.summary,
      datePublished: item.updated,
      dateModified: item.updated,
      mainEntityOfPage: url,
      url,
      image: `${PUBLIC_SITE_URL}/og/help.png`,
      author: organization,
      publisher: organization,
    },
  ];
  const steps = item.howto ? guideSteps(body) : [];
  if (steps.length) {
    graph.push({
      "@type": "HowTo",
      name: item.title,
      description: item.summary,
      step: steps.map((step, index) => ({
        "@type": "HowToStep",
        position: index + 1,
        name: step.name,
        text: step.text,
      })),
    });
  }
  const faq = guideFaq(body);
  if (faq.length) graph.push(faqPageData(faq));
  return { "@context": "https://schema.org", "@graph": graph };
}
