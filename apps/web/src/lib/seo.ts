import { getRouteAccess } from "@/lib/route-meta";

const defaultSiteUrl = "https://savestream.ronganminh221.workers.dev";
const configuredSiteUrl = import.meta.env["VITE_PUBLIC_SITE_URL"];
export const siteUrl = (configuredSiteUrl || defaultSiteUrl).replace(/\/$/, "");
export const ogImagePath = "/og-savestream.png";
export const ogImageUrl = `${siteUrl}${ogImagePath}`;

const titlePathMap: Record<string, string> = {
  "Automatic TikTok livestream recording": "/",
  Pricing: "/pricing",
  Help: "/help",
  "Contact & support": "/contact",
  "System status preview": "/status",
  "Terms of Service": "/terms",
  "Privacy Policy": "/privacy",
  "Acceptable Use Policy": "/acceptable-use",
  "Sign in": "/sign-in",
  "Create account": "/sign-up",
  "Reset password": "/forgot-password",
  "Choose new password": "/reset-password",
  "Check your email": "/verify-email",
  "Email verified": "/verify-email/success",
  "Link problem": "/auth/error",
};

const normalizePath = (path: string) => (path.startsWith("/") ? path : `/${path}`);

export function canonicalUrl(path: string) {
  return `${siteUrl}${normalizePath(path)}`;
}

export function buildSeoHead(
  title: string,
  description: string,
  path = titlePathMap[title] ?? "/__private",
) {
  const access = getRouteAccess(path);
  const fullTitle = title === "SaveStream" ? title : `${title} — SaveStream`;
  const url = canonicalUrl(path);

  const links =
    access.visibility === "public" ? [{ rel: "canonical", href: url }] : [];

  return {
    meta: [
      { title: fullTitle },
      { name: "description", content: description },
      { name: "robots", content: access.indexable ? "index,follow" : "noindex,nofollow" },
      { property: "og:title", content: fullTitle },
      { property: "og:description", content: description },
      { property: "og:type", content: "website" },
      { property: "og:url", content: url },
      { property: "og:image", content: ogImageUrl },
      { property: "og:image:width", content: "1200" },
      { property: "og:image:height", content: "630" },
      { property: "og:image:alt", content: "SaveStream automatic livestream recording" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "twitter:title", content: fullTitle },
      { name: "twitter:description", content: description },
      { name: "twitter:image", content: ogImageUrl },
    ],
    links,
  };
}

export const softwareApplicationJsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "SaveStream",
  applicationCategory: "MultimediaApplication",
  operatingSystem: "Web",
  url: siteUrl,
  description:
    "SaveStream is a frontend prototype for monitoring authorized TikTok channels and recording livestreams in the cloud.",
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "USD",
    category: "Free plan",
  },
};

export function faqJsonLd(items: readonly (readonly [string, string])[]) {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: items.map(([question, answer]) => ({
      "@type": "Question",
      name: question,
      acceptedAnswer: { "@type": "Answer", text: answer },
    })),
  };
}

export function pricingProductJsonLd(priceMonthlyUsd: number) {
  return {
    "@context": "https://schema.org",
    "@type": "Product",
    name: "SaveStream Pro",
    description: "Monthly SaveStream Pro plan for authorized livestream recording.",
    brand: { "@type": "Brand", name: "SaveStream" },
    offers: {
      "@type": "Offer",
      price: priceMonthlyUsd.toFixed(2),
      priceCurrency: "USD",
      availability: "https://schema.org/PreOrder",
      url: canonicalUrl("/pricing"),
    },
  };
}
