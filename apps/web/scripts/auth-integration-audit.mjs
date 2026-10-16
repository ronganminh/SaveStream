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

if (failures.length) {
  console.error("Auth integration audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Auth integration audit passed.");
