import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const failures = [];

const must = (file, text) => {
  if (!read(file).includes(text)) failures.push(file + ": missing " + JSON.stringify(text));
};
const forbid = (file, text) => {
  if (read(file).includes(text)) failures.push(file + ": forbidden " + JSON.stringify(text));
};
const block = (file, start, end) => {
  const source = read(file);
  const from = source.indexOf(start);
  const to = source.indexOf(end, from + start.length);
  if (from < 0 || to < 0) {
    failures.push(file + ": could not locate block " + start);
    return "";
  }
  return source.slice(from, to);
};
const mustIn = (label, source, text) => {
  if (!source.includes(text)) failures.push(label + ": missing " + JSON.stringify(text));
};
const forbidIn = (label, source, text) => {
  if (source.includes(text)) failures.push(label + ": forbidden " + JSON.stringify(text));
};

[
  '"/v1/admin/recordings"',
  '"/v1/admin/audit"',
  '"/v1/admin/operations/snapshot"',
  "/v1/admin/recordings/",
  "/retry",
].forEach((text) => must("src/repositories/api.ts", text));

[
  'pathname.startsWith("/admin")',
  'requiredRole: "admin"',
  'requiresAuth: true',
].forEach((text) => must("src/lib/app-config.ts", text));


[
  'ADMIN_ROLES = ["owner", "support", "finance", "admin"]',
  "isAdminRole(identity.role)",
].forEach((text) => must("src/lib/app-config.ts", text));

[
  '"/v1/admin/security/mfa"',
  '"/v1/admin/step-up"',
  "/v1/admin/admins",
  '"X-Admin-Step-Up"',
].forEach((text) => must("src/repositories/admin-api.ts", text));

[
  "AdminMfaGate",
  "SaveStream requires an authenticator app for every administrator.",
  "Re-enter your password, current authenticator code, and the reason for this action.",
  "AdminOwnerAccessPanel",
  "AdminDataTable",
  "AdminMetricCard",
  "AdminTimeline",
  "Search email, user ID, order ID, recording ID, or request ID",
  "adminFoundationApi.search",
].forEach((text) => must("src/components/admin/foundation.tsx", text));

[
  "AdminSystemPage",
  "AdminWorkersPage",
  "AdminJobsPage",
  "AdminJobDetailPage",
  "AdminErrorsPage",
  "AdminMfaGate",
].forEach((text) => must("src/components/admin/pages.tsx", text));

[
  "src/routes/admin/system.tsx",
  "src/routes/admin/workers.tsx",
  "src/routes/admin/jobs.index.tsx",
  "src/routes/admin/jobs.$id.tsx",
  "src/routes/admin/errors.tsx",
].forEach((file) => must(file, "@/components/admin/pages"));


[
  "/v1/admin/users?",
  "/v1/admin/users/export.csv",
  "/v1/admin/search?",
  "/privacy/requests",
  "/privacy/export",
  "/privacy/deletion/cancel",
  "/privacy/deletion/perform",
  "/view?",
].forEach((text) => must("src/repositories/admin-api.ts", text));

[
  "Search, filter, support, and audit SaveStream accounts.",
  "Export CSV",
  "Privacy requests",
  "Finance access is read-only for user support actions.",
  "Viewing as ",
  "(read-only)",
  "Playback and download are intentionally unavailable here",
  "This never creates a user token and never allows actions.",
  "AdminMfaGate",
].forEach((text) => must("src/components/admin/user-support.tsx", text));

[
  "src/routes/admin/users.index.tsx",
  "src/routes/admin/users.$id.tsx",
].forEach((file) => must(file, "@/components/admin/user-support"));

must("src/components/app-components.tsx", '{ to: "/admin/users", label: "Users", icon: Users }');

[
  "/v1/admin/storage/summary",
  "/v1/admin/storage/orphan-scans",
  "/v1/admin/email/logs",
  "/v1/admin/email/templates",
  "/v1/admin/broadcasts",
  '"X-Admin-Step-Up"',
].forEach((text) => must("src/repositories/admin-api.ts", text));

[
  "Storage, email delivery, templates, and broadcast operations.",
  "Bounded object-storage scan.",
  "Email delivery logs",
  "The HTML shell remains version-controlled.",
  "System reaches every active account. Marketing reaches only users who opted in.",
  "Preview audience",
  "Queue broadcast",
  "Re-enter your password, current authenticator code, and the reason for this action.",
].forEach((text) => must("src/components/admin/operations-d7.tsx", text));

must("src/routes/admin/operations.tsx", "@/components/admin/operations-d7");
must("src/components/app-components.tsx", '{ to: "/admin/operations", label: "Operations", icon: HardDrive }');

["Play recording", "Download recording", "presigned", "storage_key"].forEach((text) =>
  forbid("src/components/admin/user-support.tsx", text),
);

[
  "useAdminOperationalSnapshotData",
  "refetchInterval: 10_000",
  "useAdminRecordingsData",
  "useAdminRecordingData",
  "refetchInterval: 15_000",
  "useAdminAuditData",
  "useAdminRetryRecordingMutation",
  "repositories.admin.retryRecording",
  "globalThis.crypto?.randomUUID",
].forEach((text) => must("src/hooks/use-admin-data.ts", text));

["/metrics", "X-Metrics-Token", "metrics_token"].forEach((text) =>
  forbid("src/hooks/use-admin-data.ts", text),
);

const system = block(
  "src/components/app-pages.tsx",
  "function ProductionAdminSystemPage()",
  "function DemoAdminSystemPage()",
);
[
  "useAdminOperationalSnapshotData()",
  "Active recordings",
  "Recent failed recordings",
  "Pending outbox events",
  "Unprocessed payment events",
  "Pending payment orders",
  "Paused error watches",
  "does not expose per-worker CPU",
].forEach((text) => mustIn("ProductionAdminSystemPage", system, text));
["Demo fixture", "4 / 4", "8.2 TB", "0.08%"].forEach((text) =>
  forbidIn("ProductionAdminSystemPage", system, text),
);

const pages = "src/components/app-pages-more.tsx";

const workers = block(
  pages,
  "function ProductionAdminWorkersPage()",
  "/* ---------------- Admin: workers ---------------- */",
);
[
  "useAdminOperationalSnapshotData()",
  "Per-worker telemetry is not exposed by the backend",
  "Active recordings",
  "Pending outbox",
  "Recent failures",
  "Paused error watches",
].forEach((text) => mustIn("ProductionAdminWorkersPage", workers, text));
["useState(workerList)", "Drain worker", "Recent logs (placeholder)", "setList("].forEach(
  (text) => forbidIn("ProductionAdminWorkersPage", workers, text),
);

const jobs = block(
  pages,
  "function ProductionAdminJobsPage()",
  "/* ---------------- Admin: jobs ---------------- */",
);
[
  "useAdminRecordingsData(",
  "useAdminRetryRecordingMutation()",
  "recording.actions.can_retry",
  "adminSourceLabel(recording)",
  "recording.actual_cost",
].forEach((text) => mustIn("ProductionAdminJobsPage", jobs, text));
["jobList", ".stuck", "Mark as failed", "stale heartbeat"].forEach((text) =>
  forbidIn("ProductionAdminJobsPage", jobs, text),
);

const detail = block(
  pages,
  "function ProductionAdminJobDetailPage()",
  "function DemoAdminJobDetailPage()",
);
[
  "useAdminRecordingData(id)",
  "useAdminRetryRecordingMutation()",
  "item.actions.can_retry",
  "Backend recording state",
  "admin retry endpoint",
].forEach((text) => mustIn("ProductionAdminJobDetailPage", detail, text));
["jobList.find", "Mark as failed", "JobEventTimeline", "worker process is stopped"].forEach(
  (text) => forbidIn("ProductionAdminJobDetailPage", detail, text),
);

const auditPage = block(
  pages,
  "function ProductionAdminErrorsPage()",
  "/* ---------------- Admin: errors ---------------- */",
);
[
  "useAdminAuditData()",
  "useAdminOperationalSnapshotData()",
  "Audit log is not a raw service-error stream",
  "Recent recording failures",
  "Pending outbox",
  "Unprocessed payment events",
  "Paused error watches",
  "JSON.stringify(selected.details, null, 2)",
].forEach((text) => mustIn("ProductionAdminErrorsPage", auditPage, text));
["systemEvents", "Severity", "EventState", "stack (placeholder)"].forEach((text) =>
  forbidIn("ProductionAdminErrorsPage", auditPage, text),
);

must("src/components/app-components.tsx", 'label: isDemoMode ? "Errors" : "Audit"');

const d0Backend = read("../../backend/src/app/api/routes/admin.py");
[
  '"ADMIN_MFA_REQUIRED"',
  'alias="X-Admin-Step-Up"',
  '"admin:users:read"',
  '"admin:payments:refund"',
  '"admin:credits:adjust"',
  'reason=payload.reason',
].forEach((text) => {
  if (!d0Backend.includes(text)) failures.push("D0 backend invariant: missing " + JSON.stringify(text));
});

const roles = read("../../backend/src/app/domain/identity/types.py");
['"owner"', '"support"', '"finance"', '"admin:*"'].forEach((text) => {
  if (!roles.includes(text)) failures.push("D0 role matrix: missing " + JSON.stringify(text));
});


const d1Backend = read("../../backend/src/app/api/routes/admin.py");
[
  '"admin:users:read"',
  '"admin:users:write"',
  '"admin.user.viewed_as"',
  '"admin.user.privacy_exported"',
  '"admin.users.exported"',
  'alias="X-Admin-Step-Up"',
  'PrivacyService(session).anonymize_user',
].forEach((text) => {
  if (!d1Backend.includes(text)) failures.push("D1 backend invariant: missing " + JSON.stringify(text));
});

const d1Test = read("../../backend/tests/test_v2_d1_admin_users.py");
[
  'principal("support")',
  'principal("finance")',
  '"artifact" not in rendered',
  '"download_url" not in rendered',
  'support_money.status_code == 403',
  'finance_write.status_code == 403',
  '"admin.user.viewed_as"',
].forEach((text) => {
  if (!d1Test.includes(text)) failures.push("D1 backend test: missing " + JSON.stringify(text));
});

const d7Backend = read("../../backend/src/app/api/routes/admin.py");
[
  '"admin.storage.orphan_scan_queued"',
  '"admin.storage.orphans_delete_queued"',
  '"admin.email.logs_viewed"',
  '"admin.email.template_updated"',
  '"admin.broadcast.queued"',
  'alias="X-Admin-Step-Up"',
  "_require_owner(principal)",
].forEach((text) => {
  if (!d7Backend.includes(text)) failures.push("D7 backend invariant: missing " + JSON.stringify(text));
});

const d7Worker = read("../../backend/src/app/infrastructure/admin/d7_worker.py");
[
  'NotificationPreference.marketing.is_(True)',
  '_RATE_LIMIT_SECONDS',
  '"admin_system"',
  '"admin_marketing"',
  'MinioStorageClient(settings).list_keys',
].forEach((text) => {
  if (!d7Worker.includes(text)) failures.push("D7 worker invariant: missing " + JSON.stringify(text));
});

const d7Privacy = read("../../backend/src/app/application/privacy/service.py");
if (!d7Privacy.includes("timedelta(days=90)")) {
  failures.push("D7 email log retention: missing 90 day pruning");
}

const backend = read("../../backend/src/app/api/routes/admin.py");
["_require_admin(principal)", '"FORBIDDEN"', '"Admin permission is required"'].forEach(
  (text) => {
    if (!backend.includes(text)) failures.push("backend admin RBAC: missing " + JSON.stringify(text));
  },
);

const backendTest = read("../../backend/tests/test_phase8_admin_api.py");
[
  'forbidden = client.get("/v1/admin/users")',
  "assert forbidden.status_code == 403",
].forEach((text) => {
  if (!backendTest.includes(text)) failures.push("backend admin test: missing " + JSON.stringify(text));
});

if (failures.length) {
  console.error("Admin operations audit failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log("Admin operations audit passed.");
