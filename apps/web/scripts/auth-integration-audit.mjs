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

must("src/api/auth.ts", '"/v1/auth/register"');
must("src/api/auth.ts", '"/v1/auth/verify-email"');
must("src/api/auth.ts", '"/v1/auth/login"');
must("src/api/auth.ts", '"/v1/auth/social"');
must("src/api/auth.ts", '"/v1/auth/social/link"');
must("src/auth/auth-context.tsx", "signInWithSocial");
must("src/lib/firebase-social-login.ts", "signInWithPopup");
must("src/lib/firebase-social-login.ts", "inMemoryPersistence");
must("src/components/app-pages.tsx", "Continue with Google");
must("src/components/app-pages.tsx", "Continue with Apple");
must("src/components/app-pages.tsx", 'placeholder="you@example.com"');
must("src/components/app-components.tsx", 'placeholder="Password"');
forbid("src/lib/firebase-social-login.ts", "localStorage");

must("src/api/auth.ts", '"/v1/auth/refresh"');
must("src/api/auth.ts", '"/v1/auth/logout"');
must("src/api/auth.ts", '"/v1/auth/forgot-password"');
must("src/api/auth.ts", '"/v1/auth/reset-password"');
must("src/api/auth.ts", '"/v1/me"');

must("src/api/client.ts", "configureApiSession");
must("src/api/client.ts", "skipAuthRefresh");
must("src/api/client.ts", "response.status === 401");
must("src/api/client.ts", "if (refreshError) throw refreshError");
must("src/auth/auth-context.tsx", "refreshInFlightRef");
must("src/auth/auth-context.tsx", "accessTokenRef");
must("src/auth/auth-context.tsx", "AuthProvider");
must("src/auth/auth-context.tsx", "isSessionRejected");
must("src/auth/auth-context.tsx", "retryDelayMs");
must("src/auth/auth-context.tsx", "Math.min(1_000 * 2 ** retryAttempt, 10_000)");
must("src/auth/auth-guards.tsx", '"/sign-in"');
must("src/auth/auth-guards.tsx", '"/overview"');
must("src/routes/__root.tsx", "AuthRouteGuard");
must("src/routes/__root.tsx", "AuthProvider");
must("src/components/app-pages.tsx", "authApi.register");
must("src/components/app-pages.tsx", "authApi.forgotPassword");
must("src/components/app-pages.tsx", "authApi.resetPassword");
must("src/components/app-pages-more.tsx", ".verifyEmail(token)");
must("src/components/app-pages-more.tsx", ".resendVerification(email)");
must("src/components/app-components.tsx", "signOut");
must("src/components/app-components.tsx", '<Logo homeTo="/overview" />');
must("src/components/app-pages.tsx", "restoringExistingSession");
must("src/components/app-pages.tsx", 'status === "authenticated"');
// Signed-in visitors on public pages get "Buy credits" in the header.
must("src/components/app-pages.tsx", '<Link to="/billing">');
must("src/components/app-pages-more.tsx", "<ProductionContactContent embedded />");
forbid("src/components/app-pages.tsx", "Lemon Squeezy");
forbid("src/components/app-pages-more.tsx", "Lemon Squeezy");
forbid("src/lib/app-config.ts", "getFrontendIdentity()");
forbid("src/auth/auth-context.tsx", "localStorage");
forbid("src/api/auth.ts", "localStorage");

// Sign-up with Google/Apple (P0, 2026-10-16): a click before the consent
// checkboxes are ticked must answer next to the buttons, and a ticked click
// must start OAuth with the consent attached.
{
  const legal = await import(path.join(root, "src/lib/legal.ts"));
  const check = (label, ok) => {
    if (!ok) failures.push(`socialSignUpGate: ${label}`);
  };
  const none = legal.socialSignUpGate("google", false, false);
  check("blocks with nothing ticked", none.ok === false);
  check(
    "message asks to agree to continue",
    /^Please agree to the Terms of Use/.test(none.message),
  );
  check("message names the provider", none.message.endsWith("continue with Google."));
  check(
    "focuses the first checkbox",
    none.focus === "agree" && none.agreeMissing && none.aupMissing,
  );
  const aupOnly = legal.socialSignUpGate("apple", true, false);
  check(
    "blocks without AUP",
    aupOnly.ok === false && aupOnly.focus === "aup" && !aupOnly.agreeMissing,
  );
  check("names Apple", aupOnly.message.endsWith("continue with Apple."));
  check("passes when both ticked", legal.socialSignUpGate("google", true, true).ok === true);

  // The consent the web sends must be the version the API accepts.
  const backendLegal = fs.readFileSync(
    path.join(root, "../../backend/src/app/application/identity/legal.py"),
    "utf8",
  );
  const backendVersion = (name) => backendLegal.match(new RegExp(`${name} = "([^"]+)"`))?.[1];
  const consent = legal.currentLegalConsent();
  check(
    "terms version matches backend",
    consent.terms_version === backendVersion("CURRENT_TERMS_VERSION"),
  );
  check(
    "privacy version matches backend",
    consent.privacy_version === backendVersion("CURRENT_PRIVACY_VERSION"),
  );
  check(
    "AUP version matches backend",
    consent.aup_version === backendVersion("CURRENT_AUP_VERSION"),
  );
}
must("src/components/app-pages.tsx", "socialSignUpGate(provider, agreed, aupAgreed)");
must("src/components/app-pages.tsx", 'id="social-consent-error"');
must("src/components/app-pages.tsx", 'scrollIntoView({ behavior: "smooth", block: "center" })');
must("src/components/app-pages.tsx", 'mode === "sign-up" ? currentLegalConsent() : undefined');

// Latency fixes (QA report 2026-10-16, owner-approved 2026-10-21).
{
  const check = (label, ok) => {
    if (!ok) failures.push(`latency: ${label}`);
  };
  // 1. Refresh the access token before it expires (no 401 -> refresh -> retry).
  const expiry = await import(path.join(root, "src/auth/token-expiry.ts"));
  const jwt = (exp) => `h.${Buffer.from(JSON.stringify({ exp })).toString("base64url")}.s`;
  const now = 1_800_000_000_000;
  check("reads exp", expiry.accessTokenExpiresAt(jwt(now / 1000 + 900)) === now + 900_000);
  check("unreadable token -> null", expiry.accessTokenExpiresAt("garbage") === null);
  check("fresh token kept", expiry.needsEarlyRefresh(jwt(now / 1000 + 900), now) === false);
  check(
    "refresh within 60 s of expiry",
    expiry.needsEarlyRefresh(jwt(now / 1000 + 45), now) === true,
  );
  check("expired token refreshes", expiry.needsEarlyRefresh(jwt(now / 1000 - 5), now) === true);
  check("no token -> no early refresh", expiry.needsEarlyRefresh(null, now) === false);

  // 2. A GET that does not answer in 15 s is abandoned and tried once more.
  const timeout = await import(path.join(root, "src/api/request-timeout.ts"));
  check(
    "GET limit is 15 s",
    timeout.GET_TIMEOUT_MS === 15_000 && timeout.GET_TIMEOUT_RETRIES === 1,
  );
  const hanging = () => (_url, init) =>
    new Promise((_resolve, reject) =>
      init.signal.addEventListener("abort", () =>
        reject(new DOMException("Aborted", "AbortError")),
      ),
    );
  let calls = 0;
  const neverAnswers = (url, init) => {
    calls += 1;
    return hanging()(url, init);
  };
  try {
    await timeout.fetchWithTimeout(
      neverAnswers,
      "https://api.test/v1/me",
      {},
      { timeoutMs: 30, retries: 1 },
    );
    check("hanging GET throws", false);
  } catch (error) {
    check("hanging GET throws RequestTimeoutError", error instanceof timeout.RequestTimeoutError);
    check("hanging GET tried twice", calls === 2);
  }
  calls = 0;
  const secondTryAnswers = (url, init) => {
    calls += 1;
    return calls === 1 ? hanging()(url, init) : Promise.resolve(new Response("ok"));
  };
  const retried = await timeout.fetchWithTimeout(
    secondTryAnswers,
    "https://api.test/v1/me",
    {},
    { timeoutMs: 30, retries: 1 },
  );
  check("retry returns the second answer", (await retried.text()) === "ok" && calls === 2);
  calls = 0;
  const quick = () => {
    calls += 1;
    return Promise.resolve(new Response("fast"));
  };
  await timeout.fetchWithTimeout(quick, "https://api.test/v1/me", {}, { timeoutMs: 30 });
  check("fast GET sent once", calls === 1);
  calls = 0;
  const caller = new AbortController();
  setTimeout(() => caller.abort(), 5);
  try {
    await timeout.fetchWithTimeout(
      neverAnswers,
      "https://api.test/v1/me",
      { signal: caller.signal },
      { timeoutMs: 1000 },
    );
    check("caller abort throws", false);
  } catch (error) {
    check(
      "caller abort is not retried",
      !(error instanceof timeout.RequestTimeoutError) && calls === 1,
    );
  }
}
must("src/api/client.ts", "fetchWithTimeout(");
must(
  "src/api/client.ts",
  '(requestInit.method ?? "GET").toUpperCase() === "GET" && responseMode !== "response"',
);
must("src/api/client.ts", 'code: "REQUEST_TIMEOUT"');
must("src/api/client.ts", "getFreshAccessToken");
must("src/auth/auth-context.tsx", "getFreshAccessToken: async () =>");
must("src/auth/auth-context.tsx", "needsEarlyRefresh(token)");
// 3. "Restoring your session…" offers Retry after a few seconds.
must("src/components/system/system-pages.tsx", "export const RESTORE_RETRY_AFTER_MS = 4_000;");
must("src/components/system/system-pages.tsx", "This is taking longer than usual.");
must("src/auth/auth-guards.tsx", "<RestoringSessionScreen onRetry={retrySessionRestore} />");
must(
  "src/components/app-pages.tsx",
  'onRetry={status === "bootstrapping" ? retrySessionRestore : undefined}',
);
must("src/auth/auth-context.tsx", "refreshInFlightRef.current = null;\n    setRestoreAttempt");
// Authenticated queries wait for the restored session.
must("src/hooks/use-admin-data.ts", "enabled: signedIn,\n    refetchInterval: 10_000,");

if (failures.length) {
  console.error("Auth integration audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Auth integration audit passed.");
