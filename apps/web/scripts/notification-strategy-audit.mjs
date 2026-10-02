import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const failures = [];

const must = (file, text) => {
  if (!read(file).includes(text)) failures.push(`${file}: missing ${JSON.stringify(text)}`);
};
const forbid = (file, text) => {
  if (read(file).includes(text)) failures.push(`${file}: forbidden ${JSON.stringify(text)}`);
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

for (const text of [
  'UnsupportedBackendCapabilityError("persisted notifications")',
  "async markRead()",
  "async markAllRead()",
]) {
  must("src/repositories/api.ts", text);
}

for (const text of [
  "isDemoMode",
  "demoNotifications.map",
  "useNotificationRecordingFeedData",
  "initializedRecordingSnapshot",
  "syncRecordingTransitions",
  'recording.backendStatus === "recording"',
  'recording.backendStatus === "completed"',
  'recording.backendStatus === "failed"',
  'recording.backendStatus === "stopped"',
  "MAX_SESSION_NOTIFICATIONS",
  'time: "Just now"',
]) {
  must("src/lib/notification-store.ts", text);
}

must(
  "src/lib/notification-store.ts",
  "let state: Notification[] = isDemoMode",
);
forbid(
  "src/lib/notification-store.ts",
  "let state: Notification[] = demoNotifications",
);

for (const text of [
  "useNotificationRecordingFeedData",
  "refetchInterval: isDemoMode ? false : 5000",
]) {
  must("src/hooks/use-domain-data.ts", text);
}

const pages = "src/components/app-pages-more.tsx";
const prodSettings = block(
  pages,
  "function ProductionNotificationSettings()",
  "function LegacyNotificationSettings()",
);
for (const text of [
  "Current-session feed",
  "not persisted across reloads, sign-ins, or devices",
  "Recording started",
  "Recording ready",
  "Recording ended",
  "no notification-preferences API",
  "Issue #57",
]) {
  mustIn("ProductionNotificationSettings", prodSettings, text);
}
for (const text of [
  "<Switch",
  "Notification preferences saved",
  "Quota warning",
  "Retention / expiration warning",
]) {
  forbidIn("ProductionNotificationSettings", prodSettings, text);
}

const page = block(
  pages,
  "export function NotificationsPage()",
  "/* ---------------- Billing return pages",
);
for (const text of [
  "Temporary recording activity from this browser session.",
  "Temporary in-app notifications",
  "not stored by the backend yet",
  "Persisted notification history and delivery preferences are not available yet.",
]) {
  mustIn("NotificationsPage", page, text);
}
forbidIn("NotificationsPage", page, 'subtitle="Recording activity, failures, and quota alerts."');

const topbar = block(
  "src/components/app-components.tsx",
  "export function AppTopbar",
  "export function LanguageMenu",
);
mustIn("AppTopbar", topbar, "Session only");

must(
  "src/routes/notifications.tsx",
  "temporary in-app recording activity observed during the current browser session",
);
must(
  "src/routes/settings.notifications.tsx",
  "Review the current SaveStream notification scope and backend limitations.",
);

if (failures.length) {
  console.error("Notification strategy audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Notification strategy audit passed.");
