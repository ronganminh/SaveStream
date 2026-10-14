/** Cloudflare Turnstile site key for public forms; when empty the widget is not rendered. */
export const turnstileSiteKey = (import.meta.env["VITE_TURNSTILE_SITE_KEY"] ?? "").trim();
