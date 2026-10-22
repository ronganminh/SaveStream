// PostHog product analytics (owner-approved 2026-10-21): privacy rules and
// funnel wiring. Run from apps/web: npm run test:analytics
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");
const failures = [];
const must = (file, text) => {
  if (!read(file).includes(text)) failures.push(`${file}: missing ${JSON.stringify(text)}`);
};
const forbid = (file, text) => {
  if (read(file).includes(text)) failures.push(`${file}: forbidden ${JSON.stringify(text)}`);
};
const check = (name, run) => {
  try {
    run();
  } catch (error) {
    failures.push(`${name}: ${error.message}`);
  }
};

// --- privacy helpers (unit tests) --------------------------------------------
const privacy = await import(path.join(root, "src/lib/analytics-privacy.ts"));

check("staff roles are excluded", () => {
  for (const role of ["owner", "admin", "support", "finance"]) {
    assert.equal(privacy.isStaffRole(role), true, role);
  }
  assert.equal(privacy.isStaffRole("user"), false);
  assert.equal(privacy.isStaffRole(undefined), false);
});

check("admin pages are never tracked", () => {
  const pageview = (pathname) => ({
    event: "$pageview",
    properties: { $pathname: pathname, $current_url: `https://savestream.online${pathname}` },
  });
  assert.equal(privacy.sanitizeCapture(pageview("/admin"), "/admin"), null);
  assert.equal(privacy.sanitizeCapture(pageview("/admin/users"), "/admin/users"), null);
  // The event's own path wins over the current page and vice versa.
  assert.equal(privacy.sanitizeCapture(pageview("/admin/payments"), "/overview"), null);
  assert.equal(
    privacy.sanitizeCapture({ event: "channel_added", properties: {} }, "/admin/overview"),
    null,
  );
  assert.notEqual(privacy.sanitizeCapture(pageview("/administrator"), "/administrator"), null);
  assert.notEqual(privacy.sanitizeCapture(pageview("/overview"), "/overview"), null);
});

check("tokens, signed links and emails are stripped", () => {
  const cleaned = privacy.sanitizeCapture(
    {
      event: "$pageview",
      properties: {
        $current_url: "https://savestream.online/verify-email?token=SECRET-TOKEN#x",
        $referrer: "https://media.savestream.online/v/abc.mp4?exp=1&sig=SIGNED&email=a@b.co",
        $initial_referrer: "https://www.google.com/search?q=jane%40example.com",
        $pathname: "/reset-password",
        note: "contact jane.doe@example.com now",
        token: "phc_public_project_token",
        distinct_id: "u1",
        access_token: "abc",
        refresh_token: "abc",
        user_email: "jane@example.com",
        credits: 600,
      },
      $set: { email: "jane@example.com", plan: "trial" },
    },
    "/verify-email",
  );
  assert.equal(cleaned.properties.$current_url, "https://savestream.online/verify-email");
  assert.equal(cleaned.properties.$referrer, "https://media.savestream.online/v/abc.mp4");
  assert.equal(cleaned.properties.$initial_referrer, "https://www.google.com/search");
  assert.equal(cleaned.properties.note, "contact [redacted] now");
  // PostHog drops an event without its (public) project token.
  assert.equal(cleaned.properties.token, "phc_public_project_token");
  assert.equal(cleaned.properties.distinct_id, "u1");
  assert.equal("access_token" in cleaned.properties, false);
  assert.equal("refresh_token" in cleaned.properties, false);
  assert.equal("user_email" in cleaned.properties, false);
  assert.equal(cleaned.properties.credits, 600);
  assert.deepEqual(cleaned.$set, { plan: "trial" });
  assert.equal(JSON.stringify(cleaned).includes("SECRET-TOKEN"), false);
  assert.equal(JSON.stringify(cleaned).includes("SIGNED"), false);
  assert.equal(JSON.stringify(cleaned).includes("@"), false);
});

check("a Google/Apple sign-in counts as sign-up only for a new account", () => {
  const now = Date.parse("2026-10-21T08:00:00Z");
  assert.equal(privacy.isFreshAccount("2026-10-21T07:58:00Z", now), true);
  assert.equal(privacy.isFreshAccount("2026-10-20T08:00:00Z", now), false);
  assert.equal(privacy.isFreshAccount("not a date", now), false);
});

check("funnel event names", () => {
  assert.deepEqual(
    [...privacy.FUNNEL_EVENTS],
    [
      "signup_started",
      "signup_completed",
      "email_verified",
      "channel_added",
      "auto_record_enabled",
      "checkout_started",
    ],
  );
});

// --- SDK settings ----------------------------------------------------------------
const sdk = "src/lib/analytics.ts";
must(sdk, 'capture_pageview: "history_change"');
must(sdk, "disable_session_recording: true");
must(sdk, "autocapture: false");
must(sdk, "rageclick: false");
must(sdk, "capture_dead_clicks: false");
must(sdk, "enable_heatmaps: false");
must(sdk, "disable_surveys: true");
must(sdk, "advanced_disable_flags: true");
must(sdk, "disable_external_dependency_loading: true");
must(sdk, 'person_profiles: "identified_only"');
must(sdk, "before_send: (capture) => sanitizeCapture(capture, window.location.pathname)");
must(sdk, "posthog.opt_out_capturing();");
must(sdk, "posthog.identify(user.id)");
must(sdk, "posthog.reset();");
must(sdk, "if (navigator.webdriver) return false;");
must(sdk, "globalPrivacyControl");
must(sdk, "respect_dnt: true");
must(sdk, "isProductionMode && posthogKey.length > 0");
forbid(sdk, "user.email");
forbid("src/auth/auth-context.tsx", "identifyUser(user)"); // only id and role are passed
must("src/lib/app-config.ts", 'import.meta.env["VITE_POSTHOG_KEY"]');
must("src/lib/app-config.ts", 'import.meta.env["VITE_POSTHOG_HOST"]');
must("src/routes/__root.tsx", "useEffect(() => initAnalytics(), []);");

// --- identify / reset ---------------------------------------------------------------
const auth = "src/auth/auth-context.tsx";
must(auth, "identifyUser({ id: user.id, role: user.role })");
must(
  auth,
  "clearSession();\n      resetAnalytics();\n    }\n  }, [clearSession]);\n\n  const signOutEverywhere",
);
must(auth, "logoutAll();\n    } finally {\n      clearSession();\n      resetAnalytics();");

// --- funnel events -----------------------------------------------------------------
must("src/components/app-pages.tsx", 'track("signup_started", { method: "email" });');
must("src/components/app-pages.tsx", 'track("signup_started", { method: provider });');
must("src/components/app-pages.tsx", 'track("signup_completed", { method: "email" });');
must(auth, 'track("signup_completed", { method: provider });');
must("src/components/app-pages-more.tsx", 'track("email_verified");');
must(
  "src/hooks/use-channel-mutations.ts",
  'track("channel_added", { auto_record: input.auto_record });',
);
must(
  "src/hooks/use-channel-mutations.ts",
  'track("auto_record_enabled", { where: "add_channel" });',
);
must("src/hooks/use-channel-mutations.ts", 'track("auto_record_enabled", { where: "channel" });');
must("src/components/app-pages.tsx", 'track("checkout_started", {');
// Sent by the API instead, so they count once even with the browser closed.
for (const file of ["src/components/app-pages.tsx", "src/components/app-pages-more.tsx"]) {
  forbid(file, '"purchase_completed"');
  forbid(file, '"first_recording_ready"');
  forbid(file, '"first_recording_started"');
}

// --- Privacy Policy names PostHog (wording approved by the owner before merge) ----
must(
  "src/components/app-pages-more.tsx",
  "and PostHog, Inc. (United States) for product analytics.",
);
must("src/components/app-pages-more.tsx", 'h: "Product analytics"');
must("src/components/app-pages-more.tsx", 'const PRIVACY_LAST_UPDATED = "October 22, 2026";');
must("src/components/app-pages-more.tsx", "lastUpdated={PRIVACY_LAST_UPDATED}");
// Owner decision: no re-consent for this addition.
must("src/lib/legal.ts", 'export const PRIVACY_VERSION = "2026-10-14";');

// --- production build gets the public project token ------------------------------
const deploy = fs.readFileSync(path.join(root, "../../.github/workflows/deploy-web.yml"), "utf8");
for (const text of ["VITE_POSTHOG_KEY=", "VITE_POSTHOG_HOST=", "phc_"]) {
  if (!deploy.includes(text)) failures.push(`deploy-web.yml: missing ${JSON.stringify(text)}`);
}

if (failures.length) {
  console.error("Analytics audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Analytics audit passed.");
