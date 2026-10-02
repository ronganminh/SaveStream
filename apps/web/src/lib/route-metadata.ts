import { getRouteAccess } from "@/lib/app-config";

export const PUBLIC_SITE_URL = (
  import.meta.env["VITE_PUBLIC_SITE_URL"] || "https://savestream.online"
).replace(/\/$/, "");

const socialImage = `${PUBLIC_SITE_URL}/savestream-mark.svg`;

const baseMeta = (title: string, description: string) => [
  { title: `${title} — SaveStream` },
  { name: "description", content: description },
  { property: "og:title", content: `${title} — SaveStream` },
  { property: "og:description", content: description },
  { property: "og:type", content: "website" },
  { property: "og:image", content: socialImage },
  { name: "twitter:card", content: "summary" },
  { name: "twitter:title", content: `${title} — SaveStream` },
  { name: "twitter:description", content: description },
  { name: "twitter:image", content: socialImage },
];

export function meta(title: string, description: string) {
  return {
    meta: [
      ...baseMeta(title, description),
      { name: "robots", content: "noindex,nofollow" },
    ],
  };
}

export function publicMeta(pathname: string, title: string, description: string) {
  const canonical = `${PUBLIC_SITE_URL}${pathname === "/" ? "/" : pathname}`;
  const access = getRouteAccess(pathname);
  return {
    meta: [
      ...baseMeta(title, description),
      { name: "robots", content: access.indexable ? "index,follow" : "noindex,nofollow" },
      { property: "og:url", content: canonical },
    ],
    links: [{ rel: "canonical", href: canonical }],
  };
}
