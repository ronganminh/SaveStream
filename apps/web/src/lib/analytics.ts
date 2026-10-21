import type { PostHog } from "posthog-js";

import { isProductionMode, posthogHost, posthogKey } from "@/lib/app-config";
import { isStaffRole, sanitizeCapture, type FunnelEvent } from "@/lib/analytics-privacy";

// PostHog product analytics (owner-approved 2026-10-21). Pageviews and the
// funnel events in analytics-privacy.ts only: no session replay, no
// autocapture of clicks or inputs, no surveys/flags/heatmaps. Users are
// identified by the internal user id (never the email); staff accounts and
// /admin pages are not tracked.

let client: PostHog | null = null;
let loading: Promise<void> | null = null;
let staff = false;
const pending: Array<(posthog: PostHog) => void> = [];

export const analyticsEnabled = isProductionMode && posthogKey.length > 0;

function browserAllowsAnalytics(): boolean {
  if (typeof window === "undefined") return false;
  // Automated browsers (Playwright e2e against production, crawlers).
  if (navigator.webdriver) return false;
  // Global Privacy Control; Do Not Track is handled by respect_dnt below.
  return !(navigator as Navigator & { globalPrivacyControl?: boolean }).globalPrivacyControl;
}

function withClient(run: (posthog: PostHog) => void) {
  if (!analyticsEnabled || !browserAllowsAnalytics()) return;
  if (client) {
    run(client);
    return;
  }
  pending.push(run);
  initAnalytics();
}

/** Load posthog-js once, after the app has rendered (not in the SSR bundle path). */
export function initAnalytics() {
  if (!analyticsEnabled || !browserAllowsAnalytics() || loading) return;
  loading = import("posthog-js")
    .then(({ default: posthog }) => {
      posthog.init(posthogKey, {
        api_host: posthogHost,
        // SPA navigation: one $pageview per route change.
        capture_pageview: "history_change",
        capture_pageleave: false,
        autocapture: false,
        rageclick: false,
        capture_dead_clicks: false,
        enable_heatmaps: false,
        disable_session_recording: true,
        disable_surveys: true,
        disable_product_tours: true,
        disable_conversations: true,
        disable_web_experiments: true,
        advanced_disable_flags: true,
        capture_exceptions: false,
        capture_performance: false,
        // Load nothing else from PostHog's CDN at runtime.
        disable_external_dependency_loading: true,
        mask_all_text: true,
        mask_personal_data_properties: true,
        // Anonymous visitors count in pageviews but get no person profile.
        person_profiles: "identified_only",
        persistence: "localStorage",
        respect_dnt: true,
        before_send: (capture) => sanitizeCapture(capture, window.location.pathname),
      });
      client = posthog;
      for (const run of pending.splice(0)) run(posthog);
    })
    .catch(() => {
      // Analytics must never break the app (ad blockers, offline).
      pending.length = 0;
    });
}

/** Call with the signed-in account; staff accounts opt this browser out. */
export function identifyUser(user: { id: string; role: string }) {
  staff = isStaffRole(user.role);
  withClient((posthog) => {
    if (staff) {
      posthog.opt_out_capturing();
      return;
    }
    if (posthog.has_opted_out_capturing()) posthog.opt_in_capturing({ captureEventName: false });
    if (posthog.get_distinct_id() !== user.id) posthog.identify(user.id);
  });
}

/** Sign-out: the next visitor on this browser starts anonymous. */
export function resetAnalytics() {
  withClient((posthog) => {
    if (!posthog.has_opted_out_capturing()) posthog.reset();
  });
}

export function track(
  event: FunnelEvent,
  properties: Record<string, string | number | boolean> = {},
) {
  if (staff) return;
  withClient((posthog) => {
    posthog.capture(event, properties);
  });
}
