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
must("src/api/auth.ts", '"/v1/auth/refresh"');
must("src/api/auth.ts", '"/v1/auth/logout"');
must("src/api/auth.ts", '"/v1/auth/forgot-password"');
must("src/api/auth.ts", '"/v1/auth/reset-password"');
must("src/api/auth.ts", '"/v1/me"');

must("src/api/client.ts", "configureApiSession");
must("src/api/client.ts", "skipAuthRefresh");
must("src/api/client.ts", "response.status === 401");
must("src/auth/auth-context.tsx", "refreshInFlightRef");
must("src/auth/auth-context.tsx", "accessTokenRef");
must("src/auth/auth-context.tsx", "AuthProvider");
must("src/auth/auth-guards.tsx", '"/sign-in"');
must("src/auth/auth-guards.tsx", '"/overview"');
must("src/routes/__root.tsx", "AuthRouteGuard");
must("src/routes/__root.tsx", "AuthProvider");
must("src/components/app-pages.tsx", "authApi.register");
must("src/components/app-pages.tsx", "authApi.forgotPassword");
must("src/components/app-pages.tsx", "authApi.resetPassword");
must("src/components/app-pages-more.tsx", "authApi.verifyEmail");
must("src/components/app-pages-more.tsx", "authApi.resendVerification");
must("src/components/app-components.tsx", "signOut");
forbid("src/lib/app-config.ts", "getFrontendIdentity()");
forbid("src/auth/auth-context.tsx", "localStorage");
forbid("src/api/auth.ts", "localStorage");

if (failures.length) {
  console.error("Auth integration audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Auth integration audit passed.");
