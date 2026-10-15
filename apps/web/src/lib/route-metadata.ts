import { getRouteAccess } from "@/lib/app-config";

export const PUBLIC_SITE_URL = (
  import.meta.env["VITE_PUBLIC_SITE_URL"] || "https://savestream.online"
).replace(/\/$/, "");

/** 1200×630 share images in public/og (see docs/redesign). */
export type SocialImage = "home" | "pricing" | "help";

/** Every page title is "<Page name> | SaveStream" (the same in og:/twitter:title). */
export function pageTitle(name: string) {
  return `${name} | SaveStream`;
}

const baseMeta = (
  title: string,
  description: string,
  image: SocialImage = "home",
  type: "website" | "article" = "website",
) => {
  const heading = pageTitle(title);
  const imageUrl = `${PUBLIC_SITE_URL}/og/${image}.png`;
  return [
    { title: heading },
    { name: "description", content: description },
    { property: "og:title", content: heading },
    { property: "og:description", content: description },
    { property: "og:type", content: type },
    { property: "og:site_name", content: "SaveStream" },
    { property: "og:image", content: imageUrl },
    { property: "og:image:width", content: "1200" },
    { property: "og:image:height", content: "630" },
    { name: "twitter:card", content: "summary_large_image" },
    { name: "twitter:title", content: heading },
    { name: "twitter:description", content: description },
    { name: "twitter:image", content: imageUrl },
  ];
};

export function meta(title: string, description: string) {
  return {
    meta: [...baseMeta(title, description), { name: "robots", content: "noindex,nofollow" }],
  };
}

export function publicMeta(
  pathname: string,
  title: string,
  description: string,
  image: SocialImage = "home",
  type: "website" | "article" = "website",
) {
  const canonical = `${PUBLIC_SITE_URL}${pathname === "/" ? "/" : pathname}`;
  const access = getRouteAccess(pathname);
  return {
    meta: [
      ...baseMeta(title, description, image, type),
      { name: "robots", content: access.indexable ? "index,follow" : "noindex,nofollow" },
      { property: "og:url", content: canonical },
    ],
    links: [{ rel: "canonical", href: canonical }],
  };
}
