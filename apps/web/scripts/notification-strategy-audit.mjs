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
  'withQuery("/v1/notifications", { limit: 100 })',
  "/v1/notifications/mark-all-read",
  "/v1/me/notification-preferences",
  "mapNotificationToModel",
]) {
  must("src/repositories/api.ts", text);
}
forbid("src/repositories/api.ts", 'UnsupportedBackendCapabilityError("persisted notifications")');

for (const text of [
  "useNotificationsData",
  "repositories.notifications.markRead",
  "repositories.notifications.markAllRead",
  "replaceState(query.data)",
]) {
  must("src/lib/notification-store.ts", text);
}
for (const text of [
  "useNotificationRecordingFeedData",
  "initializedRecordingSnapshot",
  "syncRecordingTransitions",
  "MAX_SESSION_NOTIFICATIONS",
  'time: "Just now"',
]) {
  forbid("src/lib/notification-store.ts", text);
}

for (const text of [
  "refetchInterval: isDemoMode ? false : 10_000",
  "useNotificationPreferencesData",
  "useUpdateNotificationPreferencesMutation",
]) {
  must("src/hooks/use-notifications.ts", text);
}

const pages = "src/components/app-pages-more.tsx";
const prodSettings = block(
  pages,
  "function ProductionNotificationSettings()",
  "function DemoNotificationSettings()",
);
for (const text of [
  "In-app notification preferences",
  "stored by the backend",
  "useNotificationPreferencesData",
  "useUpdateNotificationPreferencesMutation",
  "<Switch",
  "Save preferences",
  "In-app delivery only",
]) {
  mustIn("ProductionNotificationSettings", prodSettings, text);
}
for (const text of [
  "backend does not expose persisted notifications yet",
  "Issue #57",
  "Current-session feed",
]) {
  forbidIn("ProductionNotificationSettings", prodSettings, text);
}

const page = block(
  pages,
  "export function NotificationsPage()",
  "/* ---------------- Billing return pages",
);
for (const text of [
  "Persisted recording activity",
  "Synced across devices",
  "persisted by the backend",
  "Could not load notifications",
]) {
  mustIn("NotificationsPage", page, text);
}
for (const text of [
  "Temporary recording activity",
  "Temporary in-app notifications",
  "not stored by the backend yet",
  "Persisted notification history and delivery preferences are not available yet",
]) {
  forbidIn("NotificationsPage", page, text);
}

const topbar = block(
  "src/components/app-components.tsx",
  "export function AppTopbar",
  "export function CommandSearch",
);
forbidIn("AppTopbar", topbar, "Session only");

must(
  "src/routes/notifications.tsx",
  "persisted recording lifecycle notifications and durable read state",
);
must(
  "src/routes/settings.notifications.tsx",
  "Manage persisted in-app recording notification preferences.",
);

if (failures.length) {
  console.error("Notification integration audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Notification integration audit passed.");
