import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const failures = [];

const must = (file, text) => {
  if (!read(file).includes(text)) failures.push(`${file}: missing ${JSON.stringify(text)}`);
};
const block = (file, start, end) => {
  const source = read(file);
  const from = source.indexOf(start);
  const to = source.indexOf(end, from + start.length);
  if (from < 0 || to < 0) {
    failures.push(`${file}: could not locate block ${start}`);
    return "";
  }
  return source.slice(from, to);
};
const mustIn = (label, source, text) => {
  if (!source.includes(text)) failures.push(`${label}: missing ${JSON.stringify(text)}`);
};
const forbidIn = (label, source, text) => {
  if (source.includes(text)) failures.push(`${label}: forbidden ${JSON.stringify(text)}`);
};

for (const endpoint of [
  '"/v1/me"',
  '"/v1/me/sessions"',
  '"/v1/me/export"',
]) must("src/repositories/api.ts", endpoint);

must("src/repositories/api.ts", 'apiClient.delete<{ message: string }>("/v1/me")');
must("src/repositories/api.ts", 'apiClient.delete<void>(`/v1/me/sessions/${id}`)');

for (const text of ["resendVerification(email: string)", "forgotPassword(email: string)", "logoutAll()"]) {
  must("src/api/auth.ts", text);
}
for (const text of ["signOutEverywhere", "authApi.logoutAll()", "clearSession()"]) {
  must("src/auth/auth-context.tsx", text);
}
for (const text of ["currentUser", "sessions", "useCurrentUserData", "useSessionsData"]) {
  must("src/hooks/use-domain-data.ts", text);
}
for (const text of [
  "useUpdateProfileMutation",
  "useRevokeSessionMutation",
  "useExportAccountMutation",
  "useDeleteAccountMutation",
  "useResendVerificationMutation",
  "useRequestPasswordResetMutation",
]) must("src/hooks/use-account-settings.ts", text);

const pages = "src/components/app-pages-more.tsx";
const account = block(pages, "function ProductionAccountSettings()", "function LegacyAccountSettings()");
for (const text of [
  "useCurrentUserData()",
  "useUpdateProfileMutation()",
  "useExportAccountMutation()",
  "useDeleteAccountMutation()",
  "useResendVerificationMutation()",
  "refreshSession",
  'new Blob([JSON.stringify(payload, null, 2)]',
  'anchor.download = "savestream-account-export.json"',
  "readOnly",
  "Email changes and profile images are not currently supported by the backend.",
  "Account deletion requested",
]) mustIn("ProductionAccountSettings", account, text);
for (const text of [
  "setEmail(",
  "Image upload is mocked",
  "Profile image removed",
  "We’ll email you a download link",
]) forbidIn("ProductionAccountSettings", account, text);

const security = block(pages, "function ProductionSecuritySettings()", "function LegacySecuritySettings()");
for (const text of [
  "useSessionsData()",
  "useRevokeSessionMutation()",
  "useRequestPasswordResetMutation()",
  "signOutEverywhere",
  "Email password reset link",
  "Not supported by the current SaveStream backend.",
]) mustIn("ProductionSecuritySettings", security, text);
for (const text of [
  "<PasswordField",
  "Password updated",
  "setList(",
  "Google sign-in isn’t connected in this prototype.",
]) forbidIn("ProductionSecuritySettings", security, text);

if (failures.length) {
  console.error("Account settings audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Account settings audit passed.");
