// No "@/..." imports: the analytics audit unit-tests this module with plain node.

/** Product funnel events (owner-approved 2026-10-21). */
export const FUNNEL_EVENTS = [
  "signup_started",
  "signup_completed",
  "email_verified",
  "channel_added",
  "auto_record_enabled",
  "checkout_started",
] as const;
// first_recording_started, first_recording_ready and purchase_completed are
// sent by the API (backend/src/app/application/analytics.py), so a recording
// that starts while the browser is closed, or a payment confirmed by webhook,
// still counts once.

export type FunnelEvent = (typeof FUNNEL_EVENTS)[number];

export type SignupMethod = "email" | "google" | "apple";

const STAFF_ROLES = new Set(["owner", "admin", "support", "finance"]);

/** Owner/admin/support/finance accounts are left out of the numbers. */
export function isStaffRole(role: string | null | undefined): boolean {
  return Boolean(role && STAFF_ROLES.has(role));
}

/** Admin pages are never tracked, whoever opens them. */
export function isUntrackedPath(pathname: string | null | undefined): boolean {
  if (!pathname) return false;
  return pathname === "/admin" || pathname.startsWith("/admin/");
}

/**
 * Drop the query string and fragment: they can hold verify/reset tokens,
 * order ids from PayPal returns, OAuth codes or signed media parameters.
 */
export function stripUrl(value: string): string {
  const cut = value.search(/[?#]/);
  return cut === -1 ? value : value.slice(0, cut);
}

const EMAIL = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
const SECRET_KEY = /email|token|password|secret|signature|authorization|cookie/i;
const URL_LIKE = /^(https?:)?\/\//i;

function cleanValue(key: string, value: unknown): unknown {
  if (typeof value !== "string") return value;
  if (key === "$pathname" || key.endsWith("_pathname")) return stripUrl(value);
  if (URL_LIKE.test(value) || key.endsWith("_url") || key.endsWith("referrer")) {
    return stripUrl(value).replace(EMAIL, "[redacted]");
  }
  return value.replace(EMAIL, "[redacted]");
}

// Set by the SDK itself: `token` is the public project token PostHog needs
// to accept the event, not a credential.
const SDK_KEYS = new Set(["token", "distinct_id"]);

export function cleanProperties(
  properties: Record<string, unknown> | undefined,
): Record<string, unknown> | undefined {
  if (!properties) return properties;
  const cleaned: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(properties)) {
    if (SDK_KEYS.has(key)) {
      cleaned[key] = value;
      continue;
    }
    if (SECRET_KEY.test(key)) continue;
    cleaned[key] = cleanValue(key, value);
  }
  return cleaned;
}

type Capture = {
  event: string;
  properties: Record<string, unknown>;
  $set?: Record<string, unknown>;
  $set_once?: Record<string, unknown>;
};

/**
 * PostHog before_send hook: null drops the event. Runs on every event the SDK
 * sends (pageviews included), so the rules hold even for SDK-generated ones.
 */
export function sanitizeCapture<T extends Capture>(capture: T | null, pathname: string): T | null {
  if (!capture) return null;
  const eventPath =
    typeof capture.properties["$pathname"] === "string"
      ? (capture.properties["$pathname"] as string)
      : pathname;
  if (isUntrackedPath(eventPath) || isUntrackedPath(pathname)) return null;
  const cleaned: T = { ...capture, properties: cleanProperties(capture.properties) ?? {} };
  if (capture.$set) cleaned.$set = cleanProperties(capture.$set) ?? {};
  if (capture.$set_once) cleaned.$set_once = cleanProperties(capture.$set_once) ?? {};
  return cleaned;
}

/**
 * True when an account created moments ago signed in with Google/Apple,
 * i.e. this sign-in created it (the API has no separate "created" flag).
 */
export function isFreshAccount(createdAt: string, now = Date.now(), windowMs = 10 * 60_000) {
  const created = Date.parse(createdAt);
  return Number.isFinite(created) && now - created >= -60_000 && now - created <= windowMs;
}
